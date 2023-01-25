require 'nokogiri'

module Spree
  module Export
    module Google
      class Rss
        prepend Spree::ServiceModule::Base

        def call(settings)
          @settings = settings

          return failure(store, error: "Store with id: #{settings.spree_store_id} does not exist.") if store.nil?

          builder = Nokogiri::XML::Builder.new do |xml|
            xml.rss('xmlns:g' => 'http://base.google.com/ns/1.0', 'version' => '2.0') do
              xml.channel do
                add_store_information_to_xml(xml)
                result = export_products_list.call(store)
                if result.success?
                  result.value[:products].find_each do |product|
                    product.variants.active.find_each do |variant|
                      add_variant_information_to_xml(xml, product, variant)
                    end
                  end
                end
              end
            end
          end

          success(file: builder.to_xml)
        end

        private

        def store
          return @store if defined? @store

          @store ||= Spree::Store.find_by(id: @settings.spree_store_id)
        end

        def add_store_information_to_xml(xml)
          xml.title store.name
          xml.link store.url
          xml.description store.meta_description
        end

        def add_variant_information_to_xml(xml, product, variant)
          input = { product: product, variant: variant, settings: @settings, store: store }
          result = export_required_attributes.call(input)

          if result.success
            xml.item do
              result.value[:information]&.each do |key, value|
                xml['g'].send(key, value)
              end

              add_optional_information(xml, product, variant)
              add_optional_sub_attributes(xml, product, variant)
            end
          end
        end

        def add_optional_information(xml, product, variant)
          input = { product: product, variant: variant, settings: @settings, store: store }
          result = export_optional_attributes.call(input)
          if result.success?
            information = result.value[:information]
            information.each do |key, value|
              xml['g'].send(key, value)
            end
          end
        end

        def add_optional_sub_attributes(xml, product, variant)
          input = { product: product, variant: variant, settings: @settings, store: store }
          result = export_optional_sub_attributes.call(input)
          if result.success?
            information = result.value[:information]
            information.each do |key, value|
              xml['g'].send(key) do
                value.each do |subkey, subvalue|
                  xml['g'].send(subkey, subvalue)
                end
              end
            end
          end
        end

        def export_optional_attributes
          Spree::Dependencies.export_google_optional_attributes_service.constantize.new
        end

        def export_required_attributes
          Spree::Dependencies.export_google_required_attributes_service.constantize.new
        end

        def export_optional_sub_attributes
          Spree::Dependencies.export_google_optional_sub_attributes_service.constantize.new
        end

        def export_products_list
          Spree::Dependencies.export_google_products_list.constantize.new
        end
      end
    end
  end
end
