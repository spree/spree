module Spree
  class TaxonSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.taxon_attributes
    attributes  :id, :name, :pretty_name, :permalink, :parent_id,
                :taxonomy_id

    has_many :children, root: :taxons
  end
end
