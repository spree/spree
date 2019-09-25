module Spree
  module StructuredDataHelper
    def products_structured_data(products)
      content_tag :script, type: 'application/ld+json' do
        raw(
          products.map do |product|
            structured_product_hash(product)
          end.to_json
        )
      end
    end

    private

    def structured_product_hash(product)
      {
        '@context': 'https://schema.org/',
        '@type': 'Product',
        '@id': "#{engine_routes_helper.root_url(host: current_store_host)}product_#{product.id}",
        url: engine_routes_helper.product_url(product, host: current_store_host),
        name: product.name,
        image: structured_images(product),
        description: product.description,
        sku: product.sku,
        offers: {
          '@type': 'Offer',
          price: product.price,
          priceCurrency: current_currency,
          availability: product.in_stock? ? 'InStock' : 'OutOfStock',
          url: engine_routes_helper.product_url(product, host: current_store_host),
          availabilityEnds: product.discontinue_on ? product.discontinue_on.strftime('%F') : ''
        }
      }
    end

    def structured_images(product)
      images = product.has_variants? ? product.variant_images : product.images

      return '' unless images.any?

      app_routes_helper.rails_blob_url(images.first.attachment, host: current_store_host)
    end

    def engine_routes_helper
      Spree::Core::Engine.routes.url_helpers
    end

    def app_routes_helper
      Rails.application.routes.url_helpers
    end

    def current_store_host
      current_store.url
    end
  end
end
