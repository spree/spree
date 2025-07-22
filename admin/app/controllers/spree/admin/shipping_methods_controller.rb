module Spree
  module Admin
    class ShippingMethodsController < ResourceController
      before_action :load_data, except: :index
      before_action :set_default_values, only: :new

      add_breadcrumb Spree.t(:shipping_methods), :admin_shipping_methods_path

      private

      def set_default_values
        @shipping_method.display_on = 'both'
        @shipping_method.shipping_categories = [Spree::ShippingCategory.first]
        @shipping_method.zone_ids = @available_zones.map(&:id)
        @shipping_method.calculator_type = @calculators.first.name
      end

      def load_data
        @available_zones = current_store.supported_shipping_zones
        @tax_categories = Spree::TaxCategory.order(:name)
        @calculators = Spree::ShippingMethod.calculators
        @shipping_categories = Spree::ShippingCategory.all
      end

      # needed for the inline edit of display on on the index page
      def update_turbo_stream_enabled?
        true
      end

      def permitted_resource_params
        params.require(:shipping_method).permit(permitted_shipping_method_attributes)
      end
    end
  end
end
