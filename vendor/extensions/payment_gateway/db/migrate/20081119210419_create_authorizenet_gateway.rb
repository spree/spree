class CreateAuthorizenetGateway < ActiveRecord::Migration
  def self.up
    login = GatewayOption.create(:name => "login",
                                 :description => "Your Authorize.Net API Login ID")
    password = GatewayOption.create(:name => "password",
                                    :description => "Your Authorize.Net Transaction Key.")
    test = GatewayOption.create(:name => "test",
                                :description => "If true, perform transactions against the test server. Otherwise, perform transactions against the production server.")
                                
    gateway = Gateway.create(:name => "Authorize.net",
                             :clazz => "ActiveMerchant::Billing::AuthorizeNetGateway",
                             :description => "Active Merchant's Authorize.Net Gateway.",
                             :gateway_options => [login, password, test])
  end
 
  def self.down
  end
end