class Api::ProductsController < Api::BaseController
  resource_controller_for_api
  actions :index, :show

  private

    def object_serialization_options
      { :include => [:master, :variants, :taxons] }
    end
end
