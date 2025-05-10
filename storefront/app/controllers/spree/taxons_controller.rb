module Spree
  class TaxonsController < Spree::StoreController
    include Spree::StorefrontHelper
    helper 'spree/products'

    before_action :load_taxon
    after_action :track_show, only: :show

    def show
      redirect_if_legacy_path unless turbo_frame_request? || turbo_stream_request?

      @current_page = current_theme.pages.find_by(type: 'Spree::Pages::Taxon')
    end

    private

    def accurate_title
      load_taxon unless @taxon
      @taxon.seo_title
    end

    def load_taxon
      @taxon ||= find_with_fallback_default_locale { current_store.taxons.friendly.find(params[:id]) }
    end

    def track_show
      return if turbo_frame_request? || turbo_stream_request?

      track_event('product_list_viewed', { taxon: @taxon })
    end

    def redirect_if_legacy_path
      # If an old id or a numeric id was used to find the record,
      # we should do a 301 redirect that uses the current friendly id.
      if params[:id] != @taxon.friendly_id
        redirect_to spree.nested_taxons_path(@taxon), status: :moved_permanently
      end
    end

    def default_products_sort
      @taxon.sort_order
    end
  end
end
