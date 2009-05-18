class AddCurrencyCodeOptionToPaypalGateway < ActiveRecord::Migration
  def self.up
    currency_code = GatewayOption.create(:name => "currency_code",
                                         :textarea => false,
                                         :description => "The currency you want to use (EUR, USD, refer to paypal doc)")
    gateway = Gateway.find(:first, :conditions => [ 'name = ?', "Paypal - Website Payments Pro"] )
    raise 'Failed to find Paypal gateway to add currency_code' unless gateway
    gateway.gateway_options << currency_code
  end

  def self.down
  end
end
