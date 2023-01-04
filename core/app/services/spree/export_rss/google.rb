require 'nokogiri'

module Spree
  module ExportRss
    class Google
      def call(options)
        store = Spree::Store.find(options.spree_store_id)
        @options = options

        builder = Nokogiri::XML::Builder.new do |xml|
          xml.rss('xmlns:g' => 'http://base.google.com/ns/1.0', 'version' => '2.0') do
            xml.channel do
              store_information(xml, store)
              Spree::Product.find_each do |product|
                product.variants.each do |variant|
                  next unless validate_variant(variant, product)

                  xml.item do
                    required_product_information(xml, variant, product)
                    optional_information(xml, product)
                  end
                end
              end
            end
          end
        end

        builder.to_xml
      end

      private

      def required_product_information(xml, variant, product)
        xml['g'].id variant.id
        xml['g'].title variant.sku
        xml['g'].description product.description
        xml['g'].link product.slug
        xml['g'].image_link get_image_link(variant, product)
        xml['g'].price format_price(variant)
        xml['g'].availability get_availability(product)
        xml['g'].availability_date product.available_on.xmlschema
      end

      def optional_information(xml, product)
        @options.true_keys.each do |key|
          if @options.send(key) && !product.property(key.to_s).nil?
            xml['g'].send(key, product.property(key.to_s))
          end
        end
      end

      def validate_product(product)
        unless product.deleted_at.nil?
          false
        end
        true
      end

      def validate_variant(variant, product)
        unless variant.deleted_at.nil?
          false
        end
        # TODO: make variant sku and description fallback to product's if they are nil
        if variant.id.nil? || variant.sku.nil? || variant.description.nil? || variant.slug.nil? || get_image_link(variant, product).nil?
          false
        end
        true
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

      def get_availability(product)
        return 'in stock' if product.available_on.past?
        return 'backorder' unless product.available_on.nil?

        'out of stock'
      end

      def format_price(variant)
        "#{variant.cost_price} #{variant.cost_currency}"
      end

      def store_information(xml, store)
        xml.title store.name
        xml.link store.url
        xml.description store.meta_description
      end
    end
  end
end
