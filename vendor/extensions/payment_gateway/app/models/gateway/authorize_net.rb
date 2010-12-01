class Gateway::AuthorizeNet < Gateway
	preference :login, :string
	preference :password, :string

  def provider_class
    ActiveMerchant::Billing::AuthorizeNetGateway
  end

  def options
    # add :test key in the options hash, as that is what the ActiveMerchant::Billing::AuthorizeNetGateway expects
    self.class.default_preferences[:test] = true if self.prefers? :test_mode
    super
  end
end
