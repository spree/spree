# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class ShippingExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/shipping"

  define_routes do |map|
    map.namespace :admin do |admin|
      admin.resources :shipping_method
    end  
  end
  
  def activate
    # admin.tabs.add "Shipping", "/admin/shipping", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Shipping"
  end
  
end