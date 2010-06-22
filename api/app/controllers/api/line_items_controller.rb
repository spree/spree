class Api::LineItemsController < Api::BaseController
  resource_controller_for_api
  actions :index, :show, :update, :create
  belongs_to :order

  private

    def collection_serialization_options
      { :include => [:variant], :methods => [:description] }
    end
    
    def object_serialization_options
      collection_serialization_options
    end

end
