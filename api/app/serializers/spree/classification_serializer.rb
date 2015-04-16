module Spree
  class ClassificationSerializer < ActiveModel::Serializer
    attributes :id, :position, :taxon_id

    has_one :taxon, serializer: Spree::TaxonNoChildrenSerializer
  end
end
