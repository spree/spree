class Gateway::Linkpoint < Gateway
	preference :login, :string
	preference :pem, :string

  def provider_class
    ActiveMerchant::Billing::LinkpointGateway
  end
end