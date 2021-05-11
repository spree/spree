module Spree
  module Api
    module V2
      module Platform
        class TaxonSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          attributes :pretty_name, :seo_title

          attribute :is_root do |taxon|
            taxon.root?
          end

          attribute :is_child do |taxon|
            taxon.child?
          end

          attribute :is_leaf do |taxon|
            taxon.leaf?
          end

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
end
