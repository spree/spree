module Spree
  module Admin
    module MetafieldsHelper
      def sorted_metafields(resource, display_on: nil)
        metafield_definitions = Spree::MetafieldDefinition.for_resource_type(resource.class.to_s)
        metafield_definitions = metafield_definitions.where(display_on: display_on) if display_on.present?
        metafield_definitions = metafield_definitions.order(:name)

        metafield_definitions.map do |definition|
          existing_metafield = resource.metafields.find { |mf| mf.metafield_definition_id == definition.id }
          existing_metafield || resource.metafields.build(metafield_definition: definition)
        end
      end

      def metafield_definition_resource_types
        Rails.application.config.spree.metafield_enabled_resources.map(&:to_s)
      end

      def metafield_definition_kinds
        Spree::MetafieldDefinition::AVAILABLE_KINDS
      end
    end
  end
end
