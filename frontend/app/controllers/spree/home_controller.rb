module Spree
  class HomeController < Spree::StoreController
    helper 'spree/products'
    respond_to :html

    def index
      @products = build_searcher(:Product, params).search
      @taxonomies = Spree::Taxonomy.includes(root: :children)
    end
  end
end
