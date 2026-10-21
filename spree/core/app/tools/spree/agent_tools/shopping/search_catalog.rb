module Spree
  module AgentTools
    module Shopping
      # UCP `search_catalog`, over the storefront's own product search — so an
      # agent sees the merchant's boosts, sort and catalog narrowing, not a raw
      # table scan that disagrees with what the storefront shows.
      class SearchCatalog < Tool
        self.ucp_object = :catalog_search

        tool_name 'search_catalog'
        description 'Search the store\'s products. catalog: {query?, filters?: {categories?: [category ids], ' \
                    'price?: {min?, max?} in minor units}, pagination?: {cursor?, limit?}, context?: {currency?}}. ' \
                    'An empty query lists the catalog. Each product lists the variants that can go in a cart.'

        param :catalog, type: :object, required: true,
                        description: 'The search request: query, filters and pagination.'

        DEFAULT_LIMIT = 10
        MAX_LIMIT = 50

        def call(catalog:, meta: nil)
          catalog = object(catalog)
          return invalid_argument(:catalog) if catalog.nil?

          pagination = object(catalog[:pagination]) || {}
          page = [Integer(pagination[:cursor].presence || 1, exception: false).to_i, 1].max
          limit = Integer(pagination[:limit].presence || DEFAULT_LIMIT, exception: false).to_i.clamp(1, MAX_LIMIT)
          # Filtered and priced in one currency, named explicitly, so a price
          # filter means the same amounts the results are shown in.
          currency = currency_for(catalog)

          response = store_api(:get, 'products', params: {
            q: filters(catalog, currency), currency: currency, page: page, limit: limit, expand: PRODUCT_EXPANSIONS
          })
          return failure(response) unless response.success?

          page_info = response.meta.to_h
          {
            ucp: Ucp.envelope(:catalog_search),
            products: Array(response.data).map { |product| Ucp.product(product) },
            pagination: {
              has_next_page: page_info['next'].present?,
              cursor: page_info['next']&.to_s,
              total_count: page_info['count']
            }.compact
          }
        end

        def summary(arguments)
          query = object(object(arguments)&.dig(:catalog))&.dig(:query)
          query.present? ? "Search for #{query}" : 'Browse the catalog'
        end

        private

        def filters(catalog, currency)
          filters = object(catalog[:filters]) || {}
          price = object(filters[:price]) || {}

          {
            search: catalog[:query].presence&.to_s,
            in_categories: Array(filters[:categories]).map(&:to_s).presence,
            price_gte: major(price[:min], currency),
            price_lte: major(price[:max], currency)
          }.compact
        end

        def currency_for(catalog)
          requested = object(catalog[:context])&.dig(:currency).to_s.upcase
          context.store.supported_currencies_list.map(&:iso_code).include?(requested) ? requested : context.store.default_currency
        end

        # A price filter arrives in minor units; the Store API filters in
        # major units, written as a canonical decimal string.
        def major(amount, currency)
          units = Integer(amount, exception: false) if amount.present?
          return if units.nil?

          Spree::Money::Rounding.format(Spree::Money::Rounding.from_minor_units(units, currency), currency)
        end
      end
    end
  end
end
