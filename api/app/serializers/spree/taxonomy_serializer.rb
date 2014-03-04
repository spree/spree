module Spree
  class TaxonomySerializer < ActiveModel::Serializer
    attributes :id, :name, :root_taxon

    def root_taxon
      Spree::TaxonomyTaxonSerializer.new(object.root)
    end
  end
end