module Spree
  module Admin
    class ShippingMethodsController < ResourceController
      before_action :load_data, except: :index
      before_action :set_shipping_category, only: [:create, :update]
      before_action :set_zones, only: [:create, :update]

      def update
        invoke_callbacks(:update, :before)
        if update_calculator_attributes && @object.update(permitted_shipping_method_params)
          invoke_callbacks(:update, :after)
          respond_with(@object) do |format|
            format.html do
              flash[:success] = flash_message_for(@object, :successfully_updated)
              redirect_to location_after_save
            end
            format.js { render layout: false }
          end
        else
          invoke_callbacks(:update, :fails)
          respond_with(@object) do |format|
            format.html { render action: :edit }
            format.js { render layout: false }
          end
        end
      end

      def destroy
        @object.destroy

        flash[:success] = flash_message_for(@object, :successfully_removed)

        respond_with(@object) do |format|
          format.html { redirect_to collection_url }
          format.js { render_js_for_destroy }
        end
      end

      protected

      def permitted_shipping_method_params
        params.require(resource.object_name).permit(permitted_shipping_method_attributes)
      end

      def permitted_calculator_params
        params.require(resource.object_name).require('calculator_attributes').permit(permitted_calculator_attributes)
      end

      private

      def set_shipping_category
        return true if params['shipping_method'][:shipping_categories].blank?

        @shipping_method.shipping_categories = Spree::ShippingCategory.where(id: params['shipping_method'][:shipping_categories])
        @shipping_method.save
        params[:shipping_method].delete(:shipping_categories)
      end

      def set_zones
        return true if params['shipping_method'][:zones].blank?

        @shipping_method.zones = Spree::Zone.where(id: params['shipping_method'][:zones])
        @shipping_method.save
        params[:shipping_method].delete(:zones)
      end

      def location_after_save
        edit_admin_shipping_method_path(@shipping_method)
      end

      def load_data
        @available_zones = Zone.order(:name)
        @tax_categories = Spree::TaxCategory.order(:name)
        @calculators = ShippingMethod.calculators.sort_by(&:name)
      end

      def update_calculator_attributes
        @object.calculator.type == permitted_shipping_method_params[:calculator_type] ? @object.calculator.update(permitted_calculator_params) : true
      end
    end
  end
end
