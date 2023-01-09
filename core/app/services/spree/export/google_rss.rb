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
              Spree::Product.find_each do |product|
                product.variants.active.each do |variant|
                  add_variant_information_to_xml(xml, product, variant)
                end
              end
            end
          end
        end

        builder.to_xml
      end

      private

      def format_title(product, variant)
        title = product.name
        variant.option_values.find_each do |option_value|
          title << " - #{option_value.name}"
        end
        title
      end

      def add_variant_information_to_xml(xml, product, variant)
        return if get_image_link(variant, product).nil?

        xml.item do
          add_product_information_to_xml(xml, variant, product)
        end
      end

      def add_product_information_to_xml(xml, variant, product)
        xml['g'].id variant.id
        xml['g'].title format_title(product, variant)
        xml['g'].description get_description(product, variant)
        xml['g'].link product.slug
        xml['g'].image_link get_image_link(variant, product)
        xml['g'].price format_price(variant)
        xml['g'].availability get_availability(product)
        xml['g'].availability_date product.available_on.xmlschema

        add_optional_information(xml, product)
      end

      def get_description(product, variant)
        return product.description unless product.description.nil?

        format_title(product, variant)
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
