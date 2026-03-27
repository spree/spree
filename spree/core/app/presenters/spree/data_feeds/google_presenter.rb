require 'nokogiri'

module Spree
  module DataFeeds
    class GooglePresenter < BasePresenter
      # @return [String] RSS XML feed for Google Merchant Center
      def call
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.rss('xmlns:g' => 'http://base.google.com/ns/1.0', 'version' => '2.0') do
            xml.channel do
              build_store_info(xml)
              build_items(xml)
            end
          end
        end

        builder.to_xml
      end

      private

      def build_store_info(xml)
        xml.title store.name
        xml.link store.url
        xml.description store.meta_description
      end

      def build_items(xml)
        products.includes(:variants_including_master, :properties, :product_properties).find_each do |product|
          product.variants_including_master.active.each do |variant|
            next if variant.is_master? && product.has_variants?

            build_item(xml, product, variant)
          end
        end
      end

      def build_item(xml, product, variant)
        image_url = image_link(variant, product)
        return if image_url.nil?

        xml.item do
          build_required_attributes(xml, product, variant, image_url)
          build_optional_attributes(xml, product)
        end
      end

      def build_required_attributes(xml, product, variant, image_url)
        xml['g'].id variant.id
        xml['g'].item_group_id product.id
        xml['g'].title format_title(product, variant)
        xml['g'].description product.description || format_title(product, variant)
        xml['g'].link "#{store.url}/products/#{product.slug}"
        xml['g'].image_link image_url
        xml['g'].price "#{variant.price} #{variant.cost_currency}"
        xml['g'].availability availability(product)
        xml['g'].availability_date product.available_on.xmlschema if product.available_on.present?
      end

      def build_optional_attributes(xml, product)
        product.product_properties.includes(:property).each do |product_property|
          name = product_property.property&.name
          value = product_property.value

          next if name.blank? || value.blank?

          xml['g'].send(name, value)
        end
      end

      def format_title(product, variant)
        parts = [product.name]
        variant.option_values.each do |option_value|
          parts << option_value.name
        end
        parts.join(' - ')
      end

      def image_link(variant, product)
        image = variant.thumbnail || product.thumbnail
        return if image.nil?

        Rails.application.routes.url_helpers.cdn_image_url(image.attachment.variant(:xlarge))
      end

      def availability(product)
        return 'in stock' if product.available? && (product.available_on.nil? || product.available_on.past?)
        return 'backorder' if product.backorderable? && product.backordered? && product.available_on&.future?

        'out of stock'
      end
    end
  end
end
