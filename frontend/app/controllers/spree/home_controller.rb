module Spree
  class HomeController < Spree::StoreController
    helper 'spree/products'
    respond_to :html

    def index
      @bestsellers_products = load_taxon_products('Bestsellers')
      @trending_products = load_taxon_products('Trending')
      @ld_products_updated_at = products_updated_at.map(&:to_i).join('-')

      fresh_when etag: etag, last_modified: last_modified, public: true
    end

    private

    def load_taxon_products(taxon_name)
      Spree::Product.joins(:taxons).
        where(spree_taxons: { name: taxon_name }).
        includes(
          :tax_category,
          variants: [
            { images: { attachment_attachment: :blob } }
          ],
          master: [
            :prices,
            { images: { attachment_attachment: :blob } }
          ]
        ).
        active(current_currency).
        order('spree_products_taxons.position').
        limit(12)
    end

    def products_updated_at
      @products_updated_at ||= [
        @bestsellers_products&.maximum(:updated_at),
        @trending_products&.maximum(:updated_at)
      ].compact
      @products_updated_at
    end

    def etag
      [
        store_etag,
        products_updated_at,
        additional_cache_key
      ]
    end

    def last_modified
      (products_updated_at + [current_store.updated_at]).max.utc
    end

    def additional_cache_key
      # add your own project specific cache key here
    end
  end
end
