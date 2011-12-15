module Spree
  class Gateway::Stripe < Gateway
    preference :login, :string

    # Make sure to have Spree::Config[:auto_capture] set to true.

    def provider_class
      ActiveMerchant::Billing::StripeGateway
    end

    def payment_profiles_supported?
      true
    end

    def purchase(money, creditcard, gateway_options)
      options = {}
      options[:description] = "Spree Order ID: #{gateway_options[:order_id]}"
      if customer = creditcard.gateway_customer_profile_id
        options[:customer] = customer
        creditcard = nil
      end
      provider.purchase(money, creditcard, options)
    end

    def authorize(money, creditcard, gateway_options)
      raise "Stripe does not currently support separate auth and capture; ensure Spree::Config[:auto_capture] is set to true"
    end

    def capture(authorization, creditcard, gateway_options)
      raise "Stripe does not currently support separate auth and capture; ensure Spree::Config[:auto_capture] is set to true"
    end

    def credit(money, creditcard, response_code, gateway_options)
      provider.credit(money, response_code, {})
    end

    def void(response_code, gateway_options)
      provider.void(response_code, {})
    end

    def create_profile(payment)
      return unless payment.source.gateway_customer_profile_id.nil?

      options = {}
      options[:email] = payment.order.email
      response = provider.store(payment.source, options)
      if response.success?
        payment.source.update_attributes!(:gateway_customer_profile_id => response.params['id'])
      else
        payment.source.gateway_error(response.message)
      end
    end
  end
end
