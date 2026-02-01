module Spree
  module Api
    module V3
      class TaxonSerializer < BaseSerializer
        typelize name: :string, permalink: :string, position: :number, depth: :number,
                 meta_title: 'string | null', meta_description: 'string | null', meta_keywords: 'string | null',
                 parent_id: 'string | null', taxonomy_id: :string, children_count: :number,
                 description: :string, description_html: :string,
                 image_url: 'string | null', square_image_url: 'string | null',
                 is_root: :boolean, is_child: :boolean, is_leaf: :boolean

        attributes :name, :permalink, :position, :depth,
                   :meta_title, :meta_description, :meta_keywords,
                   :children_count,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :parent_id do |taxon|
          taxon.parent&.prefix_id
        end

        attribute :taxonomy_id do |taxon|
          taxon.taxonomy&.prefix_id
        end

        attribute :description do |taxon|
          taxon.description&.to_plain_text.to_s
        end

        attribute :description_html do |taxon|
          taxon.description&.body&.to_s.to_s
        end

        attribute :image_url do |taxon|
          image_url_for(taxon.image)
        end

        attribute :square_image_url do |taxon|
          image_url_for(taxon.square_image)
        end

        attribute :is_root do |taxon|
          taxon.root?
        end

        attribute :is_child do |taxon|
          taxon.child?
        end

        attribute :is_leaf do |taxon|
          taxon.leaf?
        end

        # Conditional associations
        # Note: We pass empty includes to nested taxons to prevent infinite recursion
        # (e.g., ancestors trying to load their own ancestors)
        one :parent,
            resource: Spree.api.taxon_serializer,
            if: proc { params[:includes]&.include?('parent') },
            params: { includes: [] }

        many :children,
             resource: Spree.api.taxon_serializer,
             if: proc { params[:includes]&.include?('children') },
             params: { includes: [] }

        many :ancestors,
             resource: Spree.api.taxon_serializer,
             if: proc { params[:includes]&.include?('ancestors') },
             params: { includes: [] }

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { params[:includes]&.include?('metafields') }
      end
    end
  end
end
