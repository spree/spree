# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

class ShippingExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/shipping"

  def activate

    Admin::ConfigurationsController.class_eval do
      before_filter :add_shipping_links, :only => :index
      def add_shipping_links
        @extension_links << {:link => admin_shipping_methods_path, :link_text => t("ext_shipping_shipping_methods"), :description => t("ext_shipping_shipping_methods_description")}
        @extension_links << {:link => admin_shipping_categories_path, :link_text => t("ext_shipping_shipping_categories"), :description => t("ext_shipping_shipping_categories_description")}
      end
    end
    
    Variant.additional_fields += [
        {:name => 'Weight', :only => [:variant], :format => "%.2f"},
        {:name => 'Height', :only => [:variant], :format => "%.2f"},
        {:name => 'Width', :only => [:variant], :format => "%.2f"},
        {:name => 'Depth', :only => [:variant], :format => "%.2f"}
      ]

    # register Accessories product tab
    Admin::BaseController.class_eval do
      before_filter :add_shipments_tab
      
      private
      def add_shipments_tab
        @order_admin_tabs << {:name => 'Shipments', :url => "admin_order_shipments_url"}
      end
    end

    Product.class_eval do
      belongs_to :shipping_category
    end
  end
end