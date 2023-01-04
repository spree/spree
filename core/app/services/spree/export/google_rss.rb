require 'nokogiri'

module Spree
  module Export
    class GoogleRss
      def call(options)
        @store = Spree::Store.find(options.spree_store_id)
        @options = options

        builder = Nokogiri::XML::Builder.new do |xml|
          xml.rss('xmlns:g' => 'http://base.google.com/ns/1.0', 'version' => '2.0') do
            xml.channel do
              add_store_information_to_xml(xml)
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

      def add_store_information_to_xml(xml)
        xml.title @store.name
        xml.link @store.url
        xml.description @store.meta_description
      end

      def add_variant_information_to_xml(xml, product, variant)
        return if get_image_link(variant, product).nil?

        xml.item do
          xml['g'].id variant.id
          xml['g'].title format_title(product, variant)
          xml['g'].description get_description(product, variant)
          xml['g'].link "#{@store.url}/#{product.slug}"
          xml['g'].image_link get_image_link(variant, product)
          xml['g'].price format_price(variant)
          xml['g'].availability get_availability(product)
          xml['g'].availability_date product.available_on.xmlschema

          add_optional_information(xml, product)
        end
      end

      def format_title(product, variant)
        # Title of a variant is created by joining title of a product and variant's option_values, as they are
        # what differentiaties it from other variants.
        title = product.name
        variant.option_values.find_each do |option_value|
          title << " - #{option_value.name}"
        end
        title
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
        "#{variant.cost_price} #{variant.cost_currency}"
      end

      def get_availability(product)
        return 'in stock' if product.available_on.past?
        return 'backorder' unless product.available_on.nil?

        'out of stock'
      end

      def add_optional_information(xml, product)
        @options.enabled_keys.each do |key|
          if @options.send(key) && !product.property(key.to_s).nil?
            xml['g'].send(key, product.property(key.to_s))
          end
        end
      end

      # example of modifing optional information
      #
      # By default, this code assumes that any information that is not required by Google
      # (see https://support.google.com/merchants/answer/160589?hl=en) is stored in Spree::Products's properties.
      # If it's in other column you can modify add_optional_information like this:
      # def add_optional_information(xml, product)
      #         @options.enabled_keys.each do |key|
      #           if @options.send(key) && !product.property(key.to_s).nil?
      #             xml['g'].send(key, product.property(key.to_s))
      #           end
      #         end
      #         if !product.column_name.nil?
      #           xml['g'].attribute product.column_name
      #         end
      #       end
      #
      # If the column is part of variant or for example is option value, you will need to add variant to function's
      # arguments and modify code analogically as above.
      #
      # def add_optional_information(xml, product, variant)
      #   @options.enabled_keys.each do |key|
      #     if @options.send(key) && !product.property(key.to_s).nil?
      #       xml['g'].send(key, product.property(key.to_s))
      #     end
      #   end
      #   if !variant.column_name.nil?
      #     xml['g'].attribute variant.column_name
      #   end
      #   size_value = variant.option_value("size")
      #   if !size_value.nil?
      #     xml['g'].size size_value
      #   end
      # end
    end
  end
end
