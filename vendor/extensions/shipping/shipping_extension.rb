# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class ShippingExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/shipping"

  define_routes do |map|
    map.namespace :admin do |admin|
      admin.resources :shipping_methods
    end  
  end
  
  def activate
    Order.class_eval do
      include Spree::ShippingCalculator
    end    
  end
  
  def deactivate
    # admin.tabs.remove "Shipping"
  end
  
end