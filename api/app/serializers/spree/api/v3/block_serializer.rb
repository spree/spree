module Spree
  module Api
    module V3
      class BlockSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            name: resource.name,
            type: resource.type,
            position: resource.position,
            settings: resource.settings,
            content: resource.content,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include links
          base_attrs[:links] = serialize_links if include?('links')

          base_attrs
        end

        private

        def serialize_links
          resource.links.ordered.map do |link|
            page_link_serializer.new(link, nested_context('links')).as_json
          end
        end

        # Serializer dependencies
        def page_link_serializer
          Spree::Api::Dependencies.v3_storefront_page_link_serializer.constantize
        end
      end
    end
  end
end
