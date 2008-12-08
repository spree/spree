# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

class ShippingExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/shipping"

  def activate

    Order.class_eval do
      has_many :shipments, :dependent => :destroy
      include Spree::ShippingCalculator
    end    
    AddressesController.class_eval do
      # limit the countries to the ones that are possible to ship to
      def load_countries
        @countries = @order.shipping_countries
        @countries = [Country.find(Spree::Config[:default_country_id])] if @countries.empty?
      end
    end
    Admin::ConfigurationsController.class_eval do
      before_filter :add_shipping_links, :only => :index
      def add_shipping_links
        @extension_links << {:link => admin_shipping_methods_path, :link_text => Globalite.localize(:ext_shipping_shipping_methods), :description => Globalite.localize(:ext_shipping_shipping_methods_description)}
        @extension_links << {:link => admin_shipping_categories_path, :link_text => Globalite.localize(:ext_shipping_shipping_categories), :description => Globalite.localize(:ext_shipping_shipping_categories_description)}
      end
    end
    
    Variant.additional_fields += [
        {:name => 'Weight', :only => [:variant], :format => "%.2f"},
        {:name => 'Height', :only => [:variant], :format => "%.2f"},
        {:name => 'Width', :only => [:variant], :format => "%.2f"},
        {:name => 'Depth', :only => [:variant], :format => "%.2f"}
      ]
  end
end