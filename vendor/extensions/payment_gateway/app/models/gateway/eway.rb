class Gateway::Eway < Gateway
  preference :login, :string
  
  # Note: EWay supports purchase method only (no authorize method).
  # Ensure Spree::Config[:auto_capture] is set to true
  
  def provider_class
    ActiveMerchant::Billing::EwayGateway
  end
  
end
