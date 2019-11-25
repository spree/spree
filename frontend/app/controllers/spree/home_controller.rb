module Spree
  class HomeController < Spree::StoreController
    helper 'spree/products'
    respond_to :html

    def index
      @bestsellers_products = load_taxon_products('Bestsellers')
      @trending_products = load_taxon_products('Trending')
      @taxonomies = Spree::Taxonomy.includes(root: :children)

      @combined_products = [@bestsellers_products, @trending_products].flatten.uniq
    end

    private

    def load_taxon_products(taxon_name)
      Spree::Product.joins(:taxons)
                    .where(spree_taxons: { name: taxon_name })
                    .eager_load(
                      :variants_including_master,
                      master: [
                        :default_price,
                        { images: { attachment_attachment: :blob } }
                      ]
                    )
                    .available
                    .limit(12)
                    .to_a
    end
  end
end
