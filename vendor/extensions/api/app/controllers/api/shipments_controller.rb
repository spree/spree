class Api::ShipmentsController < Api::BaseController
  resource_controller_for_api
  actions :index, :show, :update, :create
  belongs_to :order

  private

    def collection_serialization_options
      { :include => {:shipping_method => {}, :address => {}, :inventory_units => {:include => :variant}},
      :except => [:shipping_method_id, :address_id] }
    end

    def object_serialization_options
      collection_serialization_options
    end
    
    def eager_load_associations
      [:shipping_method, :address, {:inventory_units => [:variant]}]
    end
      
end
