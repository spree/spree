module Spree
  module Api
    module V3
      class TaxonSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            name: resource.name,
            description: resource.description.to_plain_text,
            description_html: resource.description.to_s,
            image_url: image_url(resource.image),
            square_image_url: image_url(resource.square_image),
            has_products: resource.active_products_with_descendants.exists?,
            is_root: resource.root?,
            is_child: resource.child?,
            is_leaf: resource.leaf?,
            permalink: resource.permalink,
            position: resource.position,
            lft: resource.lft,
            rgt: resource.rgt,
            depth: resource.depth,
            meta_title: resource.meta_title,
            meta_description: resource.meta_description,
            meta_keywords: resource.meta_keywords,
            parent_id: resource.parent_id,
            taxonomy_id: resource.taxonomy_id,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include children
          base_attrs[:parent] = serialize_parent if include?('parent')
          base_attrs[:children] = serialize_children if include?('children')
          base_attrs[:taxonomy] = serialize_taxonomy if include?('taxonomy')

          base_attrs
        end

        private

        def serialize_parent
          taxon_serializer.new(resource.parent, nested_context('parent')).as_json
        end

        def serialize_children
          resource.children.map do |child|
            taxon_serializer.new(child, nested_context('children')).as_json
          end
        end

        def serialize_taxonomy
          taxonomy_serializer.new(resource.taxonomy, nested_context('taxonomy')).as_json
        end

        # Serializer dependencies
        def taxon_serializer
          Spree::Api::Dependencies.v3_storefront_taxon_serializer.constantize
        end

        def taxonomy_serializer
          Spree::Api::Dependencies.v3_storefront_taxonomy_serializer.constantize
        end
      end
    end
  end
end
