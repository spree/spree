module Spree
  module Admin
    module MetafieldsHelper
      def metafield_definition_resource_types
        Spree::MetafieldDefinition.available_resources.map do |type|
          [type.to_s.demodulize.titleize, type]
        end
      end

      def metafield_definition_types
        Spree::MetafieldDefinition.available_types.map do |type|
          [type.to_s.demodulize.titleize, type]
        end
      end
    end
  end
end
