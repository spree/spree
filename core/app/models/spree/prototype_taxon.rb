module Spree
  class PrototypeTaxon < Spree::Base
    self.table_name = 'spree_taxons_prototypes'

    belongs_to :taxon, class_name: 'Spree::Taxon'
    belongs_to :prototype, class_name: 'Spree::Prototype'
  end
end
