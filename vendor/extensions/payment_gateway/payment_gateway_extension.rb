# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'
require 'active_merchant'

class PaymentGatewayExtension < Spree::Extension
  version "1.0"
  description "Provides basic payment gateway functionality.  User specifies an ActiveMerchant compatible gateway 
  to use in the aplication."

  def activate  
    # Set the global "gateway mode" for active merchant (depending on whate environment we're in)
    ActiveMerchant::Billing::Base.gateway_mode = :test unless ENV['RAILS_ENV'] == "production"
    # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
    Spree::BaseController.class_eval { include Spree::PaymentGateway }    
    # admin.tabs.add "Payment Gateway", "/admin/payment_gateway", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Payment Gateway"
  end
end