module Spree
  module Admin
    class AdjustmentsController < ResourceController
      belongs_to 'spree/order', :find_by => :number
      destroy.after :reload_order

      def toggle_state
        redirect_to admin_order_adjustments_path(@order) if @adjustment.finalized?

        if @adjustment.immutable?
          @adjustment.fire_state_event(:open)
          flash[:success] = Spree.t(:adjustment_successfully_opened)
        else
          @adjustment.fire_state_event(:close)
          flash[:success] = Spree.t(:adjustment_successfully_closed)
        end
        redirect_to admin_order_adjustments_path(@order)
      end

      private
      def reload_order
        @order.reload
      end

      def collection
        parent.adjustments.eligible
      end
    end
  end
end
