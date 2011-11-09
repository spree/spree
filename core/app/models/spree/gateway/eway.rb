module Spree
  class Gateway::Eway < Gateway
    preference :login, :string

    # Note: EWay supports purchase method only (no authorize method).
    # Ensure Spree::Config[:auto_capture] is set to true

    def provider_class
      ActiveMerchant::Billing::EwayGateway
    end

    def options
      # add :test key in the options hash, as that is what the ActiveMerchant::Billing::EwayGateway expects
      if self.prefers? :test_mode
        self.class.default_preferences[:test] = true
      else
        self.class.default_preferences.delete(:test)
      end

      super
    end
  end
end
