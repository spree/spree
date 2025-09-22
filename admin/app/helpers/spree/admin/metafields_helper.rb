module Spree
  module Admin
    module MetafieldsHelper
      def metafield_definition_resource_types
        Rails.application.config.spree.metafield_enabled_resources.map(&:to_s)
      end

      def metafield_definition_kinds
        Spree::MetafieldDefinition::AVAILABLE_KINDS
      end
    end
  end
end
