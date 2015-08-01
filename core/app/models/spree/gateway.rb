module Spree
  class Gateway < PaymentMethod
    FROM_DOLLAR_TO_CENT_RATE = 100.0

    delegate :authorize, :purchase, :capture, :void, :credit, to: :provider

    validates :name, :type, presence: true

    preference :server, :string, default: 'test'
    preference :test_mode, :boolean, default: true

    def payment_source_class
      CreditCard
    end

    # instantiates the selected gateway and configures with the options stored in the database
    def self.current
      super
    end

    def provider
      gateway_options = options
      gateway_options.delete :login if gateway_options.has_key?(:login) and gateway_options[:login].nil?
      if gateway_options[:server]
        ActiveMerchant::Billing::Base.gateway_mode = gateway_options[:server].to_sym
      end
      @provider ||= provider_class.new(gateway_options)
    end

    def options
      self.preferences.inject({}){ |memo, (key, value)| memo[key.to_sym] = value; memo }
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
      source_ids = order.payments.where(source_type: payment_source_class.to_s, payment_method_id: self.id).pluck(:source_id).uniq
      payment_source_class.where(id: source_ids).with_payment_profile
    end

    def reusable_sources(order)
      if order.completed?
        sources_by_order order
      else
        if order.user_id
          self.credit_cards.where(user_id: order.user_id).with_payment_profile
        else
          []
        end
      end
    end
  end
end
