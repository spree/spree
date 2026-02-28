module Spree
  class Prototype < Spree.base_class
    has_prefix_id :proto

    include Spree::Metadata

    has_many :option_type_prototypes, class_name: 'Spree::OptionTypePrototype'
    has_many :option_types, through: :option_type_prototypes, class_name: 'Spree::OptionType'

    has_many :prototype_taxons, class_name: 'Spree::PrototypeTaxon'
    has_many :taxons, through: :prototype_taxons, class_name: 'Spree::Taxon'

    validates :name, presence: true
  end
end
