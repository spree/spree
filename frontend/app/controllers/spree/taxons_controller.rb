module Spree
  class TaxonsController < Spree::StoreController
    rescue_from ActiveRecord::RecordNotFound, with: :render_404
    helper 'spree/products'

    respond_to :html

    def show
      @taxon = Taxon.friendly.find(params[:id])
      return unless @taxon

      @products = build_searcher(:Product, params.merge(taxon: @taxon.id, include_images: true)).search
      @taxonomies = Spree::Taxonomy.includes(root: :children)
    end

    private

    def accurate_title
      @taxon.try(:seo_title) || super
    end
  end
end
