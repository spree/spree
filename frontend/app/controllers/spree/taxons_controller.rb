module Spree
  class TaxonsController < Spree::StoreController
    helper 'spree/products'

    respond_to :html

    def show
      @taxon = Spree::Taxon.friendly.find(params[:id])

      @searcher = build_searcher(params.merge(taxon: @taxon.id, include_images: true))
      @products = @searcher.retrieve_products
      @taxonomies = Spree::Taxonomy.includes(root: :children)
      @option_types = Spree::OptionType.includes(:option_values)
    end

    private

    def accurate_title
      @taxon.try(:seo_title) || super
    end
  end
end
