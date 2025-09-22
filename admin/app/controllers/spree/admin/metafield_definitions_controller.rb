module Spree
  module Admin
    class MetafieldDefinitionsController < ResourceController
      add_breadcrumb Spree.t(:metafield_definitions), :admin_metafield_definitions_path

      private

      def location_after_save
        collection_url
      end
    end
  end
end
