class Gateway::PayPal < Gateway
	preference :login, :string
	preference :password, :string
	preference :signature, :string
	preference :currency_code, :string

  def provider_class
		ActiveMerchant::Billing::PaypalGateway
  end	

end
