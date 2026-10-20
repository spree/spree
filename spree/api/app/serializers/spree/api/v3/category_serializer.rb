module Spree
  module Api
    module V3
      class CategorySerializer < BaseSerializer
        typelize name: :string, permalink: :string, position: :number, depth: :number,
                 meta_title: [:string, nullable: true], meta_description: [:string, nullable: true], meta_keywords: [:string, nullable: true],
                 parent_id: [:string, nullable: true], children_count: :number,
                 description: :string, description_html: :string,
                 image_url: [:string, nullable: true], square_image_url: [:string, nullable: true],
                 is_root: :boolean, is_child: :boolean, is_leaf: :boolean

        attributes :name, :permalink, :position, :depth,
                   :meta_title, :meta_description, :meta_keywords,
                   :children_count

        prefixed_id_attributes :parent

        attribute :description do |category|
          Spree::RichTextHelper.to_plain_text(category.description)
        end

        attributes :description_html

        attribute :image_url do |category|
          image_url_for(category.image)
        end

        attribute :square_image_url do |category|
          image_url_for(category.square_image)
        end

        attribute :is_root, &:root?

        attribute :is_child, &:child?

        attribute :is_leaf, &:leaf?

        # Conditional associations
        # Note: We pass empty expand to nested categories to prevent infinite recursion
        # (e.g., ancestors trying to load their own ancestors)
        one :parent,
            resource: proc { Spree.api.category_serializer },
            if: proc { expand?('parent') }

        many :children,
             resource: proc { Spree.api.category_serializer },
             if: proc { expand?('children') }

        many :ancestors,
             resource: proc { Spree.api.category_serializer },
             if: proc { expand?('ancestors') }

        many :storefront_custom_fields,
             key: :custom_fields,
             resource: proc { Spree.api.custom_field_serializer },
             if: proc { expand?('custom_fields') }
      end
    end
  end
end
