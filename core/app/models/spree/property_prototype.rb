module Spree
  class PropertyPrototype < Spree::Base
    belongs_to :prototype, class_name: 'Spree::Prototype'
    belongs_to :property, class_name: 'Spree::Property'

    validates :prototype, :property, presence: true
    validates :prototype_id, uniqueness: { scope: :property_id }
  end
end
