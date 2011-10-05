module Spree
  module Admin
    class ShippingMethodsController < ResourceController
      before_filter :load_data, :except => [:index]

      private
      def location_after_save
        edit_admin_shipping_method_path(@shipping_method)
      end

      def load_data
        @available_zones = Zone.order(:name)
        @calculators = ShippingMethod.calculators.sort_by(&:name)
      end
    end
  end
end
