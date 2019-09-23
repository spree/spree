module Spree
  module StructuredDataHelper
    def products_structured_data(products)
      content_tag :script, type: 'application/ld+json' do
        raw Spree::JsonLd::ProductsSerializer.new(
          products: products,
          host: request.host_with_port,
          currency: current_currency
        ).call.to_json
      end
    end
  end
end
