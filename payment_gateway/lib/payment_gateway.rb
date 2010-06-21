require 'active_merchant'

# Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
Creditcard.class_eval do
  # add gateway methods to the creditcard so we can authorize, capture, etc.
  include Spree::PaymentGateway
end

silence_warnings { require 'active_merchant/billing/authorize_net_cim' }

#register all payment methods
[
  Gateway::Bogus,
  Gateway::AuthorizeNet,
  Gateway::AuthorizeNetCim,
  Gateway::Eway,
  Gateway::Linkpoint,
  Gateway::PayPal,
  Gateway::SagePay,
  Gateway::Beanstream,
  PaymentMethod::Check
].each{|gw|
  begin
    gw.register
  rescue Exception => e
    $stderr.puts "Error registering gateway #{gw}: #{e}"
  end
}