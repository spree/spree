require 'nokogiri'

module Spree
  module Export
    class GoogleRss
      prepend Spree::ServiceModule::Base

      def call(settings)
        @settings = settings

        return failure(store, error: "Store with id: #{settings.spree_store_id} does not exist.") if store.nil?

        builder = Nokogiri::XML::Builder.new do |xml|
          xml.rss('xmlns:g' => 'http://base.google.com/ns/1.0', 'version' => '2.0') do
            xml.channel do
              add_store_information_to_xml(xml)
              store.products.active.each do |product|
                product.variants.active.each do |variant|
                  add_variant_information_to_xml(xml, product, variant)
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
        result = export_get_required_information.call(input)

        if result.success
          xml.item do
            result.value[:information]&.each do |key, value|
              xml['g'].send(key, value)
            end

            add_optional_information(xml, product, variant)
          end
        end
      end

      def add_optional_information(xml, product, variant)
        input = { product: product, variant: variant, settings: @settings, store: store }
        export_get_optional_information.call(input).value[:information]&.each do |key, value|
          xml['g'].send(key, value)
        end
      end

      def export_get_optional_information
        Spree::Dependencies.export_get_optional_information_service.constantize.new
      end

      def export_get_required_information
        Spree::Dependencies.export_get_required_information_service.constantize.new
      end

      # example of modifying optional information
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
