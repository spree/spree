module Spree
  module Api
    module V1
      class InventoryUnitsController < Spree::Api::BaseController
        before_action :prepare_event, only: :update

        def show
          @inventory_unit = inventory_unit
          respond_with(@inventory_unit)
        end

        def update
          authorize! :update, inventory_unit.order

          inventory_unit.transaction do
            if inventory_unit.update_attributes(inventory_unit_params)
              fire
              render :show, :status => 200
            else
              invalid_resource!(inventory_unit)
            end
          end
        end

        private

        def inventory_unit
          @inventory_unit ||= InventoryUnit.accessible_by(current_ability, :read).find(params[:id])
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
        
        def inventory_unit_params
          params.require(:inventory_unit).permit(permitted_inventory_unit_attributes)
        end
      end
    end
  end
end
