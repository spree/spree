class CreateBogusGateway < ActiveRecord::Migration
  def self.up
    gateway = Gateway.create(:name => "Bogus Gateway",
                             :clazz => "Spree::BogusGateway",
                             :description => "Simple ActiveMerchant compliant gateway that always approves credit 
                                              card purchases.  Use credit card number: 4111111111111111, card type: 
                                              visa, and card code: 123.")
    
    configuration = GatewayConfiguration.create(:id => 1, :gateway => gateway)
  end

  def self.down
  end
end