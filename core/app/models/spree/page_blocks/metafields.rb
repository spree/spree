module Spree
  module PageBlocks
    class Metafields < Spree::PageBlock
      RESOURCE_TYPE_DEFAULT = 'Spree::Product'

      preference :resource_type, :string, default: -> { self.class::RESOURCE_TYPE_DEFAULT if defined?(self.class::RESOURCE_TYPE_DEFAULT) }
      preference :metafield_definition_ids, :array, default: -> { available_metafield_definitions.pluck(:id) }

      def icon_name
        'list'
      end

      def available_metafield_definitions
        @available_metafield_definitions ||= Spree::MetafieldDefinition.where(resource_type: preferred_resource_type).available_on_front_end
      end
    end
  end
end
