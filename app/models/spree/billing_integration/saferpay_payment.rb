class Spree::BillingIntegration::SaferpayPayment < Spree::BillingIntegration
  preference :endpoint, :string, default: ::Saferpay::Configuration::DEFAULTS[:endpoint]
  preference :user_agent, :string, default: ::Saferpay::Configuration::DEFAULTS[:user_agent]
  preference :account_id, :string, default: ::Saferpay::Configuration::DEFAULTS[:account_id]
  preference :password, :string, default: 'XAjc3Kna' # Test account
  preference :currency, :string, default: "EUR"

  attr_accessible :preferred_endpoint, :preferred_user_agent,
                  :preferred_account_id, :preferred_password,
                  :preferred_currency,:preferred_server, :preferred_test_mode

  def provider_class
    ::Saferpay::API
  end

  def provider
    @provider ||= provider_class.new
  end

  def payment_profiles_supported?
    false
  end

  def payment_options order
    {
      "ACCOUNTID" => preferred_account_id,
      "AMOUNT" => amount_in_cents(order.total).to_s,
      "CURRENCY" => preferred_currency,
      "DESCRIPTION" => I18n.t(:saferpay_order_description, order: order.number),
      "LANGID" => I18n.locale,
      "ORDERID" => order.number
    }
  end

  def payment_url(order, url_options = {})
    provider.get_payment_url payment_options(order).merge(url_options)
  end

  def complete_payment(params = {})
    # We need to add account
    account_params = { "ACCOUNTID" => preferred_account_id }
    # And password justo for test account
    account_params.merge!(spPassword: preferred_password) if preferred_test_mode

    begin
      # 40 seconds of timeout, to avoid the request die
      Timeout::timeout(40) do
        provider.complete_payment(params.merge(account_params))
      end
    rescue Timeout::Error
      # The paymant successful but we get timeout on our confirm
      { successful: true, result: 'Timeout',
        message: 'Timeout for PayCompleteV2 request', id: 'UNKNOW' }
    end
  end

  def credit(*args)
    amount = args.shift
    response_code = args.first.is_a?(String) ? args.first : args[1]
    provider.credit(amount, response_code, :currency => preferred_currency)
  end

  def find_authorization(payment)
    logs = payment.log_entries.all(:order => 'created_at DESC')
    logs.each do |log|
      details = YAML.load(log.details) # return the transaction details
      if (details.params['payment_status'] == 'Pending' && details.params['pending_reason'] == 'authorization')
        return details
      end
    end
    return nil
  end

  def find_capture(payment)
    #find the transaction associated with the original authorization/capture
    logs = payment.log_entries.all(:order => 'created_at DESC')
    logs.each do |log|
      details = YAML.load(log.details) # return the transaction details
      if details.params['payment_status'] == 'Completed'
        return details
      end
    end
    return nil
  end

  def amount_in_cents(amount)
    (100 * amount.to_f).to_i
  end

end
