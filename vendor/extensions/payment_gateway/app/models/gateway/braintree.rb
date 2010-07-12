class Gateway::Braintree < Gateway
	preference :merchant_id, :string
	preference :public_key, :string
	preference :private_key, :string

  def provider_class
    ActiveMerchant::Billing::BraintreeGateway
  end

  def authorize(money, creditcard, options = {})
    adjust_options_for_braintree(creditcard, options)
    payment_method = creditcard.gateway_customer_profile_id || creditcard
    provider.authorize(money, payment_method, options)
  end

  def capture(authorization, ignored_creditcard, ignored_options)
    amount = (authorization.amount * 100).to_i
    provider.capture(amount, authorization.response_code)
  end

  def create_profile(payment)
    if payment.source.gateway_customer_profile_id.nil?
      response = provider.store(payment.source)
      if response.success?
        payment.source.update_attributes!(:gateway_customer_profile_id => response.params["customer_vault_id"])
      else
        payment.source.gateway_error response.message
      end
    end
  end

  def credit(*args)
    if args.size == 4
      credit_with_payment_profiles(*args)
    elsif args.size == 3
      credit_without_payment_profiles(*args)
    else
      raise ArgumentError, "Expected 3 or 4 arguments, received #{args.size}"
    end
  end

  def credit_with_payment_profiles(amount, payment, response_code, option)
    provider.credit(amount, payment)
  end

  def credit_without_payment_profiles(amount, response_code, options)
    transaction = ::Braintree::Transaction.find(response_code)
    if BigDecimal.new(amount.to_s) == (transaction.amount * 100)
      provider.refund(response_code)
    else
      raise NotImplementedError
    end
  end

  def payment_profiles_supported?
    true
  end

  def purchase(money, creditcard, options = {})
    authorize(money, creditcard, options.merge(:submit_for_settlement => true))
  end

  def void(response_code, ignored_creditcard, ignored_options)
    provider.void(response_code)
  end

  protected

  def adjust_country_name(options)
    [:billing_address, :shipping_address].each do |address|
      if options[address] && options[address][:country] == "US"
        options[address][:country] = "United States of America"
      end
    end
  end

  def adjust_billing_address(creditcard, options)
    if creditcard.gateway_customer_profile_id
      options.delete(:billing_address)
    end
  end

  def adjust_options_for_braintree(creditcard, options)
    adjust_country_name(options)
    adjust_billing_address(creditcard, options)
  end
end

