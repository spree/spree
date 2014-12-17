module Spree
  class HomeController < Spree::StoreController
    helper 'spree/products'
    respond_to :html

    def index
      @products = build_searcher(:Product, params.merge(include_images: true)).search
      @taxonomies = Spree::Taxonomy.includes(root: :children)
    end
  end
end
