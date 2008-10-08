# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

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
    AddressesController.class_eval do
      # limit the countries to the ones that are possible to ship to
      def load_countries
        return @countries = Country.all unless parent_model == Order
        @countries = @order.shipping_countries
        @countries = [Country.find(Spree::Config[:default_country_id])] if @countries.empty?
      end
    end
  end
  
  def deactivate
    # admin.tabs.remove "Shipping"
  end
  
end