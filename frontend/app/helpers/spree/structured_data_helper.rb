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
      Rails.cache.fetch(common_product_cache_keys + ["spree/structured-data/#{product.cache_key_with_version}"]) do
        {
          '@context': 'https://schema.org/',
          '@type': 'Product',
          '@id': "#{spree.root_url}product_#{product.id}",
          url: spree.product_url(product),
          name: product.name,
          image: structured_images(product),
          description: product.description,
          brand: structured_brand(product),
          sku: structured_sku(product),
          gtin: structured_barcode(product),
          offers: {
            '@type': 'Offer',
            price: product.default_variant.price_in(current_currency).amount,
            priceValidUntil: product.discontinue_on ? product.discontinue_on.strftime('%F') : '',
            priceCurrency: current_currency,
            availability: product.in_stock? ? 'InStock' : 'OutOfStock',
            url: spree.product_url(product),
            availabilityEnds: product.discontinue_on ? product.discontinue_on.strftime('%F') : ''
          }
        }
      end
    end

    def structured_sku(product)
      product.default_variant.sku? ? product.default_variant.sku : product.sku
    end

    def structured_brand(product)
      if product.property('brand').present?
        return product.property('brand')
      else
        return ''
      end
    end

    def structured_barcode(product)
      product.default_variant.barcode? ? product.default_variant.barcode : product.barcode
    end

    def structured_images(product)
      image = default_image_for_product_or_variant(product)

      return '' unless image

      main_app.rails_blob_url(image.attachment)
    end
  end
end
