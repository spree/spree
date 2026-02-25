module Spree
  class Gateway < PaymentMethod
    FROM_DOLLAR_TO_CENT_RATE = 100.0

    delegate :authorize, :purchase, :capture, :void, :credit, to: :provider

    validates :type, presence: true, inclusion: { in: :valid_providers_list }

    def payment_source_class
      CreditCard
    end

    # Override in the gateway to provide a payment url
    # eg. for Stripe, this would be the payment intent url
    # https://dashboard.stripe.com/payments/#{payment.transaction_id}
    def gateway_dashboard_payment_url(_payment)
      nil
    end

    def provider
      gateway_options = options
      gateway_options.delete :login if gateway_options.key?(:login) && gateway_options[:login].nil?
      @provider ||= provider_class.new(gateway_options)
    end

    def options
      preferences.each_with_object({}) { |(key, value), memo| memo[key.to_sym] = value; }
    end

    def method_missing(method, *args)
      if @provider.nil? || !@provider.respond_to?(method)
        super
      else
        provider.send(method, *args)
      end
    end

    def payment_profiles_supported?
      false
    end

    def method_type
      'gateway'
    end

    def exchange_multiplier
      FROM_DOLLAR_TO_CENT_RATE
    end

    def supports?(source)
      return true unless provider_class.respond_to? :supports?
      return false unless source.brand

      provider_class.supports?(source.brand)
    end

    def disable_customer_profile(source)
      if source.is_a? CreditCard
        source.update_column :gateway_customer_profile_id, nil
      else
        raise 'You must implement disable_customer_profile method for this gateway.'
      end
    end

    def sources_by_order(order)
      source_ids = order.payments.where(source_type: payment_source_class.to_s, payment_method_id: id).pluck(:source_id).uniq
      payment_source_class.where(id: source_ids).capturable
    end

    def reusable_sources(order)
      if order.completed?
        sources_by_order order
      else
        if order.user_id
          credit_cards.where(user_id: order.user_id).capturable
        else
          []
        end
      end
    end

    private

    def valid_providers_list
      Spree::PaymentMethod.providers.map(&:to_s)
    end
  end
end
