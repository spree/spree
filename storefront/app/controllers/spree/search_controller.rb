module Spree
  class SearchController < StoreController
    after_action :track, only: :show

    helper_method :query

    def show
      @current_page = current_theme.pages.find_by(type: 'Spree::Pages::SearchResults')
    end

    def suggestions
      @products = []
      @taxons = []

      if query.present? && query.length >= Spree::Storefront::Config.search_min_query_length
        products_scope = storefront_products_scope.multi_search(query)
        @products = products_scope.includes(storefront_products_includes)
        @taxons = current_store.taxons.search_by_name(query)
      end
    end

    private

    def query
      @query ||= params[:q].presence&.strip_html_tags&.strip
    end

    def track
      return if turbo_frame_request? || turbo_stream_request?
      return if query.blank?

      track_event('product_searched', { query: query })
    end

    def default_products_sort
      'manual'
    end
  end
end
