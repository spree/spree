module Spree
  module AgentTools
    module Shopping
      # UCP `lookup_catalog`: several products at once, by product or variant
      # id. An id that matches nothing is left out and named in an info
      # message, as the spec asks, rather than failing the whole lookup.
      class LookupCatalog < Tool
        self.ucp_object = :catalog_lookup

        tool_name 'lookup_catalog'
        description 'Look up products by product or variant ids. catalog: {ids: [...]}. ' \
                    'Each returned variant says which of the ids it matched.'

        param :catalog, type: :object, required: true, description: 'The request: {ids: [product or variant ids]}.'

        MAX_IDS = 20

        def call(catalog:, meta: nil)
          catalog = object(catalog)
          return invalid_argument(:catalog) if catalog.nil?

          ids = Array(catalog[:ids]).map(&:to_s).compact_blank.uniq
          if ids.empty? || ids.size > MAX_IDS
            return Ucp.error('invalid', "Send between 1 and #{MAX_IDS} ids.", :catalog_lookup,
                             severity: 'recoverable', path: '$.catalog.ids')
          end

          product_ids = product_ids_for(ids)
          found = fetch(product_ids.values.uniq)
          return found if found.key?(:ucp)

          missing = ids.reject { |id| found.key?(product_ids[id]) }

          {
            ucp: Ucp.envelope(:catalog_lookup),
            products: found.values.map { |json| present_product(json, ids - missing) },
            messages: missing.map { |id| { type: 'info', code: 'not_found', content: id } }.presence
          }.compact
        end

        private

        # One listing for every product asked about, so the Store API still
        # decides which of them a shopper may see. Nothing to ask for is
        # answered here: an empty id filter is no filter, and would list the
        # whole catalog.
        #
        # @return [Hash] products by id, or a UCP error
        def fetch(product_ids)
          return {} if product_ids.empty?

          response = store_api(:get, 'products', params: {
            q: { id_in: product_ids }, limit: MAX_IDS, expand: PRODUCT_EXPANSIONS
          })
          return failure(response) unless response.success?

          Array(response.data).index_by { |product| product['id'] }
        end

        # Each requested id, as the product it names. A variant id resolves to
        # its product within this store only, in one query; an id that names
        # neither is dropped, so it can never widen the listing.
        def product_ids_for(ids)
          variant_prefix = "#{Spree::Variant._prefix_id_prefix}_"
          variant_ids = ids.select { |id| id.start_with?(variant_prefix) }
          decoded = variant_ids.index_with { |id| Spree::Variant.decode_prefixed_id(id) }.compact
          products = context.store.variants.where(id: decoded.values).includes(:product).index_by(&:id)

          ids.index_with do |id|
            next products[decoded[id]]&.product&.prefixed_id if id.start_with?(variant_prefix)

            id if Spree::Product.decode_prefixed_id(id)
          end.compact
        end

        def present_product(json, inputs)
          product = Ucp.product(json)

          product[:variants].each do |variant|
            matched = inputs.include?(variant[:id]) ? variant[:id] : inputs.find { |input| input == product[:id] }
            variant[:inputs] = [{ id: matched, match: matched == variant[:id] ? 'exact' : 'featured' }] if matched
          end
          product
        end
      end
    end
  end
end
