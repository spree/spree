class Api::ProductsController < Api::BaseController
  include Spree::Search

  private
    def collection
      params[:per_page] ||= 100
      @searcher = Spree::Config.searcher_class.new(params)
      @collection = @searcher.retrieve_products
    end

    def object_serialization_options
      { :include => [:master, :variants, :taxons] }
    end
end
