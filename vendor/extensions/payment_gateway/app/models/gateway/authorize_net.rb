class Gateway::AuthorizeNet < Gateway
	preference :login, :string
	preference :password, :password
	
  def provider_class
    ActiveMerchant::Billing::AuthorizeNetGateway
  end	
end
