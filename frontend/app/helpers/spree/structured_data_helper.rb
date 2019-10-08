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
      Rails.cache.fetch("spree/structured-data/#{product.cache_key}") do
        {
          '@context': 'https://schema.org/',
          '@type': 'Product',
          '@id': "#{spree.root_url}product_#{product.id}",
          url: spree.product_url(product),
          name: product.name,
          image: structured_images(product),
          description: product.description,
          sku: product.sku,
          offers: {
            '@type': 'Offer',
            price: product.price,
            priceCurrency: current_currency,
            availability: product.in_stock? ? 'InStock' : 'OutOfStock',
            url: spree.product_url(product),
            availabilityEnds: product.discontinue_on ? product.discontinue_on.strftime('%F') : ''
          }
        }
      end
    end

    def structured_images(product)
      image = product.variant_images.first

      return '' unless image

      main_app.rails_blob_url(image.attachment)
    end
  end
end
