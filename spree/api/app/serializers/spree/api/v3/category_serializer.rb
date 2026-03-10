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
                   :children_count,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :parent_id do |category|
          category.parent&.prefixed_id
        end

        attribute :description do |category|
          category.description&.to_plain_text.to_s
        end

        attribute :description_html do |category|
          category.description&.body&.to_s.to_s
        end

        attribute :image_url do |category|
          image_url_for(category.image)
        end

        attribute :square_image_url do |category|
          image_url_for(category.square_image)
        end

        attribute :is_root do |category|
          category.root?
        end

        attribute :is_child do |category|
          category.child?
        end

        attribute :is_leaf do |category|
          category.leaf?
        end

        # Conditional associations
        # Note: We pass empty expand to nested categories to prevent infinite recursion
        # (e.g., ancestors trying to load their own ancestors)
        one :parent,
            resource: Spree.api.category_serializer,
            if: proc { expand?('parent') }

        many :children,
             resource: Spree.api.category_serializer,
             if: proc { expand?('children') }

        many :ancestors,
             resource: Spree.api.category_serializer,
             if: proc { expand?('ancestors') }

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { expand?('metafields') }
      end
    end
  end
end
