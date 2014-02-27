module Spree
  class TaxonomyTaxonSerializer < ActiveModel::Serializer
    root false
    attributes :id, :name

    has_many :children, root: :taxons, serializer: Spree::TaxonNoChildrenSerializer
  end
end