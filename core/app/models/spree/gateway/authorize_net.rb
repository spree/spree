module Spree
  class Gateway::AuthorizeNet < Gateway
    preference :login, :string
    preference :password, :string

    def provider_class
      ActiveMerchant::Billing::AuthorizeNetGateway
    end

    def options
      # add :test key in the options hash, as that is what the ActiveMerchant::Billing::AuthorizeNetGateway expects
      if self.preferred_test_mode
        self.class.preference :test, :boolean, :default => true
      else
        self.class.remove_preference :test
      end

      super
    end
  end
end
