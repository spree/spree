class Api::InventoryUnitsController < Api::BaseController
  resource_controller_for_api
  actions :index, :show, :update, :create
  belongs_to :shipment, :order

  private

    def eager_load_associations
      [:variant]
    end
      
end
