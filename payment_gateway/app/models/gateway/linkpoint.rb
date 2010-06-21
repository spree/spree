class Gateway::Linkpoint < Gateway
	preference :login, :string
	preference :pem, :text

  def provider_class
    ActiveMerchant::Billing::LinkpointGateway
  end
end