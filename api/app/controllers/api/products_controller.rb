class Api::ProductsController < Api::BaseController
  resource_controller_for_api
  actions :index, :show, :create, :update
  include Spree::Search

  private
    define_method :collection do
      @searcher = Spree::Config.searcher_class.new(params)
      @collection = @searcher.retrieve_products
    end

    def object_serialization_options
      { :include => [:master, :variants, :taxons] }
    end
end
