class Gateway::AuthorizeNet < Gateway
	preference :login, :string
	preference :password, :string
	
  def provider_class
    ActiveMerchant::Billing::AuthorizeNetGateway
  end	
end
