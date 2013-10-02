module Spree
  module Admin
    class AdjustmentsController < ResourceController
      belongs_to 'spree/order', :find_by => :number
      destroy.after :reload_order
      skip_before_filter :load_resource, :only => [:toggle_state, :edit, :update, :destroy]

      def toggle_state
        @adjustment = parent.all_adjustments.find(params[:id])
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

      def edit
        find_adjustment
        super
      end

      def update
        find_adjustment
        super
      end

      def destroy
        find_adjustment 
        super
      end

      private
      def find_adjustment
        # Need to assign to @object here to keep ResourceController happy
        @adjustment = @object = parent.all_adjustments.find(params[:id])
      end

      def reload_order
        @order.reload
      end
    end
  end
end
