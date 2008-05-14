# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

class TaxCalculatorExtension < Spree::Extension
  version "1.0"
  description "Provides basic tax calculation functionality using the contents and shipping destination of the order."

  define_routes do |map|
    map.namespace :admin do |admin|
      admin.resources :tax_rates
    end  
  end

  def activate
    # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
    CheckoutController.class_eval { include Spree::TaxCalculator }    
    # admin.tabs.add "Tax Calculator", "/admin/tax_calculator", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Tax Calculator"
  end
  
end