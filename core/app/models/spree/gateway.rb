module Spree
  class Gateway < PaymentMethod
    delegate_belongs_to :provider, :authorize, :purchase, :capture, :void, :credit

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

    def supports?(source)
      return true unless provider_class.respond_to? :supports?
      return false unless source.brand
      provider_class.supports?(source.brand)
    end
  end
end
