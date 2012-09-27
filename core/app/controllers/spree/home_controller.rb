module Spree
  class HomeController < BaseController
    helper 'spree/products'
    respond_to :html

    def index
      params[:user_id] = try_spree_current_user.id if try_spree_current_user
      @searcher = Spree::Config.searcher_class.new(params)
      @products = @searcher.retrieve_products
      respond_with(@products)
    end
  end
end
