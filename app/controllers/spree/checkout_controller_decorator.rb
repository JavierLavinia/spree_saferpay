module Spree
  Spree::CheckoutController.class_eval do
    before_filter :redirect_to_saferpay_form_if_needed, only: :update
    skip_before_filter :verify_authenticity_token, only: :saferpay_notify

    # Receive a direct notification from the gateway
    def saferpay_notify
      http_status = :ok
      load_order
      begin
        data = payment_method.provider.handle_pay_confirm(params)

        status = payment_method.complete_payment(id: data[:id]) # Settle Payment
        if status[:successful]
          unless @order.state == "complete"
            @order.payments.destroy_all
            order_upgrade
            payment_upgrade
          end
          payment = Spree::Payment.find_by_order_id(@order)
          payment.response_code = status[:result]
          payment.avs_response = "#{status[:message]} (id: #{status[:id]})"
          payment.complete!
        else
          @order.payments.destroy_all
          payment = @order.payments.create({:amount => @order.total,
                                             :source_type => 'Spree:SaferpayCreditCard',
                                             :payment_method => payment_method,
                                             :state => 'processing',
                                             :response_code => status[:result],
                                             :avs_response => "#{status[:message]} (id: #{status[:id]})"},
                                            :without_protection => true)
          payment.failure!
        end
      rescue Saferpay::Error => e
        @order.payments.destroy_all
        payment = @order.payments.create({:amount => @order.total,
                                           :source_type => 'Spree:SaferpayCreditCard',
                                           :payment_method => payment_method,
                                           :state => 'processing',
                                           :response_code => e.class.name,
                                           :avs_response => e.message},
                                          :without_protection => true)
        payment.failure!
        http_status = :error
      end
      render nothing: true, status: http_status
    end

    # Handle the incoming user
    def saferpay_confirm
      load_order
      payment_upgrade() unless @order.completed?
      flash[:notice] = I18n.t(:order_processed_successfully)
      redirect_to completion_route
    end

    # create the gateway from the supplied options
    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id]) if params[:payment_method_id]
      @payment_method ||= Spree::PaymentMethod.find_by_type("Spree::BillingIntegration::SaferpayPayment")
    end

    private

    def asset_url(_path)
      URI::HTTP.build(:path => ActionController::Base.helpers.asset_path(_path), :host => Spree::Config[:site_url]).to_s
    end


    def redirect_to_saferpay_form_if_needed
      return unless (params[:state] == "payment")
      return unless params[:order][:payments_attributes]

      if @order.update_attributes(object_params)
        if params[:order][:coupon_code] and !params[:order][:coupon_code].blank? and @order.coupon_code.present?
          fire_event('spree.checkout.coupon_code_added', :coupon_code => @order.coupon_code)
        end
      end

      load_order

      if @order.errors.any?
        render :edit and return
      end

      payment_method_id = params[:order][:payments_attributes].first[:payment_method_id]
      @payment_method = Spree::PaymentMethod.find(payment_method_id)

      if @payment_method.kind_of?(Spree::BillingIntegration::SaferpayPayment)
        order_url_options = order_url_options(@order, payment_method_id)
        redirect_to @payment_method.payment_url(@order, order_url_options)
      end
    end

    def user_locale
      I18n.locale.to_s
    end

    def saferpay_gateway
      payment_method.provider
    end

    def order_url_options order, payment_method_id
      {
        "SUCCESSLINK" => saferpay_confirm_order_checkout_url(order),
        "FAILLINK" => edit_order_checkout_url(order, state: :payment),
        "BACKLINK" => edit_order_checkout_url(order, state: :payment),
        "NOTIFYURL" => saferpay_notify_order_checkout_url(order, payment_method_id: payment_method_id)
      }
    end

    def set_cache_buster
      response.headers["Cache-Control"] = "no-cache, no-store" #post-check=0, pre-check=0
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end

    def order_upgrade
      @order.state = "payment"
      @order.save

      @order.update_attributes({:state => "complete", :completed_at => Time.now}, :without_protection => true)

      state_callback(:after) # So that after_complete is called, setting session[:order_id] to nil

      # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
      if @order.respond_to?(:consume_users_credit, true)
        @order.send(:consume_users_credit)
      end

      @order.finalize!
    end

    def payment_upgrade
      payment = @order.payments.create({:amount => @order.total,
                                        :source_type => 'Spree:SaferpayCreditCard',
                                        :payment_method => payment_method },
                                      :without_protection => true)
      payment.started_processing!
      payment.pend!
    end

  end

end
