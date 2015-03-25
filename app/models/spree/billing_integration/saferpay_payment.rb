class Spree::BillingIntegration::SaferpayPayment < Spree::BillingIntegration
  preference :endpoint, :string, default: ::Saferpay::Configuration::DEFAULTS[:endpoint]
  preference :user_agent, :string, default: ::Saferpay::Configuration::DEFAULTS[:user_agent]
  preference :account_id, :string, default: ::Saferpay::Configuration::DEFAULTS[:account_id]
  preference :currency, :string, default: "EUR"

  attr_accessible :preferred_endpoint, :preferred_user_agent,
                  :preferred_account_id, :preferred_currency,
                  :preferred_server, :preferred_test_mode

  def provider_class
    ::Saferpay::API
  end

  def provider
    @provider ||= provider_class.new
  end

  def payment_profiles_supported?
    false
  end

  def capture(payment_or_amount, account_or_response_code, gateway_options)
    if payment_or_amount.is_a?(Spree::Payment)
      authorization = find_authorization(payment_or_amount)
      provider.capture(amount_in_cents(payment_or_amount.amount), authorization.params["transaction_id"], :currency => preferred_currency)
    else
      provider.capture(payment_or_amount, account_or_response_code, :currency => preferred_currency)
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
    (100 * amount).to_i
  end

end
