module Spree
  module Admin
    class ReturnAuthorizationsController < ResourceController
      belongs_to 'spree/order', :find_by => :number
      before_filter :load_return_items, except: [:fire, :destroy, :index]
      before_filter :load_return_authorization_reasons, except: [:index, :fire, :destroy]

      def fire
        @return_authorization.send("#{params[:e]}!")
        flash[:success] = Spree.t(:return_authorization_updated)
        redirect_to :back
      end

      private

      # To satisfy how nested attributes works we want to create placeholder ReturnItems for
      # any InventoryUnits that have not already been added to the ReturnAuthorization.
      def load_return_items
        all_inventory_units = @return_authorization.order.inventory_units
        rma_inventory_units = @return_authorization.return_items.map(&:inventory_unit)

        new_units = all_inventory_units - rma_inventory_units
        new_return_items = new_units.map do |new_unit|
          Spree::ReturnItem.new(inventory_unit: new_unit, pre_tax_amount: new_unit.rounded_pre_tax_amount)
        end

        @allow_amount_edit = Spree::Config[:allow_return_item_amount_editing]
        @form_return_items = (@return_authorization.return_items + new_return_items).sort_by(&:inventory_unit_id)

        # Adjust last return item value in case rounding prevented total from being evenly distributed
        refund_total = @form_return_items.sum(&:pre_tax_amount)
        refundable_amount = @return_authorization.refundable_amount
        @form_return_items.last.pre_tax_amount += (refundable_amount - refund_total) if refund_total < refundable_amount
      end

      def load_return_authorization_reasons
        @reasons = Spree::ReturnAuthorizationReason.active
        # Only allow an inactive reason if it's already associated to the RMA
        if @return_authorization.reason && !@return_authorization.reason.active?
          @reasons << @return_authorization.reason
        end
      end
    end
  end
end
