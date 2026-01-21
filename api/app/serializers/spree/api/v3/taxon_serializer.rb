module Spree
  module Api
    module V3
      class TaxonSerializer < BaseSerializer
        attributes :id, :name, :permalink, :position, :lft, :rgt, :depth,
                   :meta_title, :meta_description, :meta_keywords,
                   :parent_id, :taxonomy_id, :children_count

        attribute :description do |taxon|
          taxon.description.to_plain_text
        end

        attribute :description_html do |taxon|
          taxon.description.to_s
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
        one :parent,
            resource: Spree.api.v3_storefront_taxon_serializer,
            if: proc { params[:includes]&.include?('parent') }

        many :children,
             resource: Spree.api.v3_storefront_taxon_serializer,
             if: proc { params[:includes]&.include?('children') }
      end
    end
  end
end
