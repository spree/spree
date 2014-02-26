module Spree
  class TaxonomyTaxonSerializer < ActiveModel::Serializer
    root false
    attributes :id, :name

    has_many :children, root: :taxons
  end
end