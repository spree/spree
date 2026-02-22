module Spree
  module Admin
    module MetafieldsHelper
      def link_to_edit_metafields(record, options = {})
        return unless Spree::MetafieldDefinition.available_resources.map(&:name).include?(record.class.name)
        return unless record.respond_to?(:metafields)
        return unless can?(:manage, record)
        return unless can?(:manage, Spree::Metafield)

        options[:class] ||= 'dropdown-item'
        options[:data]  ||= { action: 'drawer#open', turbo_frame: :drawer }

        link_to_with_icon 'edit', Spree.t(:metafields), spree.edit_admin_metafield_path(record.id, resource_type: record.class.name), options
      end

      def metafield_definition_resource_types
        @metafield_definition_resource_types ||= Spree::MetafieldDefinition.available_resources.map do |type|
          [type.to_s.demodulize.titleize, type]
        end
      end

      def metafield_definition_types
        @metafield_definition_types ||= Spree::MetafieldDefinition.available_types.map do |type|
          [type.to_s.demodulize.titleize, type]
        end
      end
    end
  end
end
