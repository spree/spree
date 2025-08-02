module Spree
  module Api
    module V2
      module Platform
        class TaxonSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :pretty_name, :seo_title

          attribute :description do |taxon|
            taxon.description.to_plain_text
          end

          attribute :header_url do |taxon|
            url_helpers.cdn_image_url(taxon.image.attachment) if taxon.image.present? && taxon.image.attached?
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

          belongs_to :parent,   record_type: :taxon, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize
          belongs_to :taxonomy, record_type: :taxonomy, serializer: Spree::Api::Dependencies.platform_taxonomy_serializer.constantize

          has_many   :children, record_type: :taxon, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize
          has_many   :products, record_type: :product,
                                serializer: Spree::Api::Dependencies.platform_product_serializer.constantize,
                                if: proc { |_taxon, params| params && params[:include_products] == true }

          has_one    :image,
                     object_method_name: :icon,
                     id_method_name: :icon_id,
                     record_type: :taxon_image,
                     serializer: Spree::Api::Dependencies.platform_taxon_image_serializer.constantize
        end
      end
    end
  end
end
