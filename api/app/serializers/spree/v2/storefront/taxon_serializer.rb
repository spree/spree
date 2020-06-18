module Spree
  module V2
    module Storefront
      class TaxonSerializer < BaseSerializer
        set_type   :taxon

        attributes :name, :pretty_name, :permalink, :seo_title, :description, :meta_title, :meta_description,
                   :meta_keywords, :left, :right, :position, :depth, :updated_at

        attribute :is_root,  &:root?
        attribute :is_child, &:child?
        attribute :is_leaf,  &:leaf?

        belongs_to :parent,   record_type: :taxon, serializer: :taxon
        belongs_to :taxonomy, record_type: :taxonomy

        has_many   :children, record_type: :taxon, serializer: :taxon
        has_many   :products, record_type: :product

        has_one    :image,
          object_method_name: :icon,
          id_method_name: :icon_id,
          record_type: :taxon_image,
          serializer: :taxon_image
      end
    end
  end
end
