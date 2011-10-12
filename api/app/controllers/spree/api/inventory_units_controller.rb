class Spree::Api::InventoryUnitsController < Spree::Api::BaseController
  private
    def parent
      if params[:order_id]
        @parent = Spree::Order.find_by_param(params[:order_id])
      elsif params[:shipment_id]
        @parent = Spree::Shipment.find_by_param(params[:shipment_id])
      end
    end

    def parent_data
      [params[:order_id], params[:shipment_id]].compact
    end

    def eager_load_associations
      [:variant]
    end
end
