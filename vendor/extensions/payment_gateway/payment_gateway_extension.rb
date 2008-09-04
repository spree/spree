# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'
require 'active_merchant'

class PaymentGatewayExtension < Spree::Extension
  version "1.0"
  description "Provides basic payment gateway functionality.  User specifies an ActiveMerchant compatible gateway 
  to use in the aplication."

  define_routes do |map|
    map.namespace :admin do |admin|
      admin.resources :gateways, :has_many => [:gateway_options]
      admin.resources :gateway_configurations, :has_many => [:gateway_option_values]
    end  
  end

  def activate  
    # Set the global "gateway mode" for active merchant (depending on whate environment we're in)
    ActiveMerchant::Billing::Base.gateway_mode = :test unless ENV['RAILS_ENV'] == "production"
    # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
    CreditcardPayment.class_eval do
      before_save :authorize
      include Spree::PaymentGateway
    end
    # admin.tabs.add "Payment Gateway", "/admin/payment_gateway", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Payment Gateway"
  end
end