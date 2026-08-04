require 'nokogiri'

module Spree
  module DataFeeds
    class GooglePresenter < BasePresenter
      # Optional Google Merchant Center product attributes sourced from
      # metafields. See https://support.google.com/merchants/answer/7052112
      OPTIONAL_ATTRIBUTES = %w[
        brand gtin mpn identifier_exists condition adult multipack is_bundle
        age_group color gender material pattern size size_type size_system
        product_length product_width product_height product_weight
        google_product_category product_type sale_price sale_price_effective_date
        cost_of_goods_sold unit_pricing_measure unit_pricing_base_measure
        shipping shipping_label shipping_weight shipping_length shipping_width
        shipping_height ships_from_country transit_time_label max_handling_time
        min_handling_time tax tax_category energy_efficiency_class
        min_energy_efficiency_class max_energy_efficiency_class
        gtin_source expiration_date custom_label_0 custom_label_1 custom_label_2
        custom_label_3 custom_label_4 mobile_link additional_image_link
      ].freeze

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
        xml.link store.storefront_url
        xml.description store.meta_description
      end

      def build_items(xml)
        products.includes(:primary_media, public_metafields: :metafield_definition, variants: [:primary_media, option_values: :option_type]).find_each do |product|
          product.variants.active.each do |variant|
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
        xml['g'].link "#{store.storefront_url}/products/#{product.slug}"
        xml['g'].image_link image_url
        xml['g'].price "#{variant.price} #{variant.cost_currency}"
        xml['g'].availability availability(product)
        xml['g'].availability_date product.available_on.xmlschema if product.available_on.present?
      end

      def build_optional_attributes(xml, product)
        product.public_metafields.each do |metafield|
          key = metafield.metafield_definition.key.parameterize.underscore
          next unless OPTIONAL_ATTRIBUTES.include?(key)

          append_g_element(xml, key, metafield.value)
        end
      end

      def append_g_element(xml, name, value)
        parent = xml.parent
        node = Nokogiri::XML::Node.new(name, parent.document)
        node.namespace = parent.namespace_scopes.find { |ns| ns.prefix == 'g' }
        node.content = value
        parent << node
      end

      def format_title(product, variant)
        parts = [product.name]
        variant.option_values.each do |option_value|
          parts << option_value.name
        end
        parts.join(' - ')
      end

      def image_link(variant, product)
        image = variant.primary_media || product.primary_media
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
