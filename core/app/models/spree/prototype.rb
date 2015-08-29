module Spree
  class Prototype < Spree::Base
    has_many :property_prototypes
    has_many :properties, through: :property_prototypes

    has_many :option_type_prototypes
    has_many :option_types, through: :option_type_prototypes

    has_many :prototype_taxons
    has_many :taxons, through: :prototype_taxons

    validates :name, presence: true
  end
end
