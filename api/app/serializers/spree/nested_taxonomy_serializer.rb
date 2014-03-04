module Spree
  class NestedTaxonomySerializer < ActiveModel::Serializer
    attributes :id, :name, :root_taxon

    def root_taxon
      Spree::NestedTaxonomyTaxonSerializer.new(object.root)
    end
  end
end