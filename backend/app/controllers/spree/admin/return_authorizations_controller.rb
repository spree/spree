module Spree
  module Admin
    class ReturnAuthorizationsController < ResourceController
      belongs_to 'spree/order', :find_by => :number
      before_filter :load_return_authorization_inventory_units, except: [:fire, :destroy, :index]

      def fire
        @return_authorization.send("#{params[:e]}!")
        flash[:success] = Spree.t(:return_authorization_updated)
        redirect_to :back
      end

      private

      # To satisfy how nested attributes works we want to create placeholder ReturnAuthorizationInventoryUnits for
      # any InventoryUnits that have not already been added to the ReturnAuthorization.
      def load_return_authorization_inventory_units
        all_inventory_unit_ids = @return_authorization.order.inventory_units.map(&:id)
        rma_inventory_unit_ids = @return_authorization.return_authorization_inventory_units.map(&:inventory_unit_id)

        new_ids = all_inventory_unit_ids - rma_inventory_unit_ids
        new_units = new_ids.map { |new_id| Spree::ReturnAuthorizationInventoryUnit.new(inventory_unit_id: new_id) }

        @form_return_authorization_inventory_units = (@return_authorization.return_authorization_inventory_units + new_units).sort_by(&:inventory_unit_id)
      end

    end
  end
end
