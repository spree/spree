module Spree
  class TaxonNoChildrenSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.taxon_attributes
    attributes :id, :name, :pretty_name, :permalink, :taxonomy_id, :parent_id
  end
end
