module Spree
  module DataFeeds
    module Google
      class RequiredAttributes
        prepend Spree::ServiceModule::Base

        def call(input)
          information = {}

          return failure(nil, error: 'No image link') if get_image_link(input[:variant], input[:product]).nil?

          information['id'] = input[:variant].id
          information['title'] = format_title(input[:product], input[:variant])
          information['description'] = get_description(input[:product], input[:variant])
          information['link'] = "#{input[:store].url}/products/#{input[:product].slug}"
          information['image_link'] = get_image_link(input[:variant], input[:product])
          information['price'] = format_price(input[:variant])
          information['availability'] = get_availability(input[:product])
          information['availability_date'] = input[:product].available_on&.xmlschema unless input[:product].available_on.nil?

          success(information: information)
        end

        private

        def format_title(product, variant)
          # Title of a variant is created by joining title of a product and variant's option_values, as they are
          # what differentiates it from other variants.
          parts = [product.name]
          variant.option_values.find_each do |option_value|
            parts << option_value.name
          end
          parts.join(' - ')
        end

        def get_description(product, variant)
          return product.description unless product.description.nil?

          format_title(product, variant)
        end

        def get_image_link(variant, product)
          # try getting image from variant
          img = variant.images.first&.plp_url

          # if no image specified for variant try getting product image
          if img.nil?
            img = product.images.first&.plp_url
          end

          img
        end

        def format_price(variant)
          "#{variant.price} #{variant.cost_currency}"
        end

        def get_availability(product)
          return 'in stock' if product.available? && (product.available_on.nil? || product.available_on.past?)
          return 'backorder' if product.backorderable? && product.backordered? && product.available_on&.future?

          'out of stock'
        end
      end
    end
  end
end
