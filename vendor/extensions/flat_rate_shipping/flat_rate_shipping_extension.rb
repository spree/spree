# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class FlatRateShippingExtension < Spree::Extension
  version "1.0"
  description "Provides FlatRate shiping_calculator" 

  # define_routes do |map|
  #   map.namespace :admin do |admin|
  #     admin.resources :whatever
  #   end  
  # end
  
  def activate
    # admin.tabs.add "Flat Rate Shipping", "/admin/flat_rate_shipping", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Flat Rate Shipping"
  end
  
  def calculate_shipping(order)
    return Spree::FlatRateShipping::Config[:flat_rate_amount]
  end
  
end