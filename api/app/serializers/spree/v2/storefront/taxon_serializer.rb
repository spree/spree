module Spree
  module V2
    module Storefront
      class TaxonSerializer < BaseSerializer
        set_type :taxon
        attributes :id, :parent_id, :position, :name, :permalink, :taxonomy_id,
                   :lft, :rgt, :description, :meta_title, :meta_description,
                   :meta_keywords
        belongs_to :taxonomy
      end
    end
  end
end
