module Spree
  module Api
    class InventoryUnitsController < Spree::Api::BaseController
      before_filter :prepare_event, :only => :update

      def show
        @inventory_unit = inventory_unit
      end

      def update
        authorize! :update, Order

        inventory_unit.transaction do
          if inventory_unit.update_attributes(params[:inventory_unit])
            fire
            render :show, :status => 200
          else
            invalid_resource!(inventory_unit)
          end
        end
      end

      private

      def inventory_unit
        @inventory_unit ||= InventoryUnit.find(params[:id])
      end

      def prepare_event
        return unless @event = params[:fire]

        can_event = "can_#{@event}?"

        unless inventory_unit.respond_to?(can_event) &&
               inventory_unit.send(can_event)
          render :text => { :exception => "cannot transition to #{@event}" }.to_json,
                 :status => 200
          false
        end
      end

      def fire
        inventory_unit.send("#{@event}!") if @event
      end

    end
  end
end
