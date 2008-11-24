# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class FlatRateShippingExtension < Spree::Extension
  version "1.0"
  description "Provides FlatRate shiping_calculator" 

  def activate
    # admin.tabs.add "Flat Rate Shipping", "/admin/flat_rate_shipping", :after => "Layouts", :visibility => [:all]
  end
end