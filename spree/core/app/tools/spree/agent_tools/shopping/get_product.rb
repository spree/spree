module Spree
  module AgentTools
    module Shopping
      # UCP `get_product`: one product with every variant a cart can hold.
      class GetProduct < Tool
        self.ucp_object = :catalog_lookup

        tool_name 'get_product'
        description 'Fetch one product by id with its options and variants. catalog: {id}. ' \
                    'Put a variant id, not the product id, in a cart.'

        param :catalog, type: :object, required: true, description: 'The request: {id}.'

        def call(catalog:, meta: nil)
          id = object(catalog)&.dig(:id).to_s
          return not_found if id.blank?

          response = store_api(:get, "products/#{ERB::Util.url_encode(id)}", params: { expand: PRODUCT_EXPANSIONS })
          return failure(response) unless response.success?

          { ucp: Ucp.envelope(:catalog_lookup), product: Ucp.product(response.data) }
        end

        def summary(arguments)
          "Look up #{object(object(arguments)&.dig(:catalog))&.dig(:id)}"
        end

        private

        def not_found
          Ucp.error('not_found', 'No product with this id. Find one with search_catalog.', :catalog_lookup)
        end
      end
    end
  end
end
