class Api::LineItemsController < Api::BaseController

  private
    def parent
      if params[:order_id]
        @parent ||= Order.find_by_param(params[:order_id])
      end
    end
  
    def parent_data
      params[:order_id]
    end
    
    def collection_serialization_options
      { :include => [:variant], :methods => [:description] }
    end

    def object_serialization_options
      collection_serialization_options
    end

end
