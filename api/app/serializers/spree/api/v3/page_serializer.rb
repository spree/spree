module Spree
  module Api
    module V3
      class PageSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            type: resource.type,
            name: resource.name,
            slug: resource.slug,
            meta_title: resource.meta_title,
            meta_description: resource.meta_description,
            meta_keywords: resource.meta_keywords,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include associations
          base_attrs[:sections] = serialize_sections if include?('sections')

          base_attrs
        end

        private

        def serialize_sections
          resource.sections.map do |section|
            section_serializer.new(section, nested_context('sections')).as_json
          end
        end

        # Serializer dependencies
        def section_serializer
          Spree::Api::Dependencies.v3_storefront_section_serializer.constantize
        end
      end
    end
  end
end
