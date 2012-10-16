module Spree
  class HomeController < BaseController
    helper 'spree/products'
    respond_to :html

    def index
      @searcher = Spree::Config.searcher_class.new(params)
      @searcher.current_user = try_spree_current_user
      @products = @searcher.retrieve_products
      respond_with(@products)
    end
  end
end
