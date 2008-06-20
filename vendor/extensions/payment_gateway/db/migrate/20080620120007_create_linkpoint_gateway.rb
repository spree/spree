class CreateLinkpointGateway < ActiveRecord::Migration
  def self.up
    login   = GatewayOption.create(:name => "login",
                                   :description => "Your store number.")
    pem     = GatewayOption.create(:name => "pem",
                                   :textarea => true,
                                   :description => "The text of your linkpoint PEM file. Note this is not the 
                                                    path to file, but its actual contents.")
                                
    gateway = Gateway.create(:name => "Linkpoint",
                             :clazz => "ActiveMerchant::Billing::LinkpointGateway",
                             :description => "Active Merchant's Linkpoint Gateway.",
                             :gateway_options => [login, pem])
  end

  def self.down
  end
end