module Spree
  module Admin
    module MetafieldsHelper
      def link_to_edit_metafields(resource, classes: 'text-left dropdown-item')
        return unless Spree::MetafieldDefinition.for_owner_type(resource.class.to_s).exists?

        link_to_with_icon(
          'tag',
          Spree.t('metafields.nav.metafields'),
          spree.edit_admin_metafield_path(resource, resource_type: resource.class.to_s),
          class: classes
        ) if can?(:update, resource)
      end

      def sorted_metafields(resource, display_on: nil)
        metafield_definitions = Spree::MetafieldDefinition.for_owner_type(resource.class.to_s)
        metafield_definitions = metafield_definitions.where(display_on: display_on) if display_on.present?
        metafield_definitions = metafield_definitions.order(:name)

        metafield_definitions.map do |definition|
          existing_metafield = resource.metafields.find { |mf| mf.metafield_definition_id == definition.id }
          existing_metafield || resource.metafields.build(metafield_definition: definition)
        end
      end

      def metafield_definition_owner_types
        Rails.application.config.spree.metafield_enabled_resources.map(&:to_s)
      end

      def metafield_definition_kinds
        Spree::MetafieldDefinition::AVAILABLE_KINDS
      end
    end
  end
end
