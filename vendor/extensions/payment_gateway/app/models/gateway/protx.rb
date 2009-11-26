class Gateway::Protx < Gateway
	preference :login, :string
	preference :password, :password
	preference :account, :string

  def provider_class
		ActiveMerchant::Billing::ProtxGateway
  end	
end
