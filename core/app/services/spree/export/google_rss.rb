require 'nokogiri'

module Spree
  module Export
    class GoogleRss
      def call(options)
        store = Spree::Store.find(options.spree_store_id)
        @options = options

        builder = Nokogiri::XML::Builder.new do |xml|
          xml.rss('xmlns:g' => 'http://base.google.com/ns/1.0', 'version' => '2.0') do
            xml.channel do
              add_store_information_to_xml(xml, store)
              Spree::Product.where('(description = \'\') IS FALSE').find_each do |product|
                product.variants.where('(sku = \'\') IS FALSE AND deleted_at is null').each do |variant|
                  add_variant_information_to_xml(xml, product, variant)
                end
              end
            end
          end
        end

        builder.to_xml
      end

      private

      def add_variant_information_to_xml(xml, product, variant)
        return if get_image_link(variant, product).nil?

        xml.item do
          add_product_information_to_xml(xml, variant, product)
        end
      end

      def add_product_information_to_xml(xml, variant, product)
        xml['g'].id variant.id
        xml['g'].title variant.sku
        xml['g'].description product.description
        xml['g'].link product.slug
        xml['g'].image_link get_image_link(variant, product)
        xml['g'].price format_price(variant)
        xml['g'].availability get_availability(product)
        xml['g'].availability_date product.available_on.xmlschema

        add_optional_information(xml, product)
      end

      def add_optional_information(xml, product)
        @options.enabled_keys.each do |key|
          if @options.send(key) && !product.property(key.to_s).nil?
            xml['g'].send(key, product.property(key.to_s))
          end
        end
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

      def add_store_information_to_xml(xml, store)
        xml.title store.name
        xml.link store.url
        xml.description store.meta_description
      end
    end
  end
end
