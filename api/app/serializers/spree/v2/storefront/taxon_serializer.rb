module Spree
  module V2
    module Storefront
      class TaxonSerializer < BaseSerializer
        set_type   :taxon

        attributes :id, :name, :pretty_name, :permalink,
                   :meta_title, :meta_description, :parent_id,
                   :taxonomy_id

        has_many   :children, record_type: :taxon, serializer: :taxon
      end
    end
  end
end
