module Spree
  class PrototypeTaxon < Spree::Base
    belongs_to :taxon, class_name: 'Spree::Taxon'
    belongs_to :prototype, class_name: 'Spree::Prototype'

    validates :prototype, :taxon, presence: true
    validates :prototype_id, uniqueness: { scope: :taxon_id }
  end
end
