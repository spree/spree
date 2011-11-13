module Spree
  class BillingIntegration < PaymentMethod
    validates :name, :presence => true

    preference :server, :string, :default => 'test'
    preference :test_mode, :boolean, :default => true

    def provider
      integration_options = options
      ActiveMerchant::Billing::Base.integration_mode = integration_options[:server].to_sym
      integration_options = options
      integration_options[:test] = true if integration_options[:test_mode]
      @provider ||= provider_class.new(integration_options)
    end

    def options
      options_hash = {}
      self.preferences.each do |key,value|
        options_hash[key.to_sym] = value
      end
      options_hash
    end
  end
end
