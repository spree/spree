class CreateProtxGateway < ActiveRecord::Migration
  def self.up
    protx = Gateway.create(
      :clazz => 'ActiveMerchant::Billing::ProtxGateway',
      :name => 'Protx',
      :description => "Active Merchant's Protx Gateway (IE/UK)" 
    ) 

    GatewayOption.create(:name => 'login', :description => 'Your Protx Login', :gateway_id => protx.id, :textarea => false)
    GatewayOption.create(:name => 'password', :description => 'Your Protx Password', :gateway_id => protx.id, :textarea => false)
    GatewayOption.create(:name => 'account', :description => 'Protx sub account name (optional)', :gateway_id => protx.id, :textarea => false)
  end

  def self.down
    protx = Gateway.find_by_name('Protx')
    protx.destroy
  end
end
