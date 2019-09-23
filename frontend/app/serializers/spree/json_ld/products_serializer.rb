module Spree
  module JsonLd
    class ProductsSerializer
      def initialize(products:, host:, currency:)
        @products = products
        @host = host
        @currency = currency
      end

      def call
        @products.map do |product|
          product_hash(product)
        end
      end

      private

      def product_hash(product)
        {
          '@context': 'https://schema.org/',
          '@type': 'Product',
          '@id': "#{engine_routes_helper.root_url(host: @host)}product_#{product.id}",
          url: engine_routes_helper.product_url(product, host: @host),
          name: product.name,
          image: images(product),
          description: product.description,
          sku: product.sku,
          offers: {
            '@type': 'Offer',
            price: product.price,
            priceCurrency: @currency,
            availability: product.in_stock? ? 'InStock' : 'OutOfStock',
            url: engine_routes_helper.product_url(product, host: @host),
            availabilityEnds: product.discontinue_on ? product.discontinue_on.strftime('%F') : ''
          }
        }
      end

      def images(product)
        images = product.has_variants? ? product.variant_images : product.images

        return '' unless images.any?

        app_routes_helper.rails_blob_url(images.first.attachment, host: @host)
      end

      def engine_routes_helper
        Spree::Core::Engine.routes.url_helpers
      end

      def app_routes_helper
        Rails.application.routes.url_helpers
      end
    end
  end
end
