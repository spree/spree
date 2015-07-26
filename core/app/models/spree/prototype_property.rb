module Spree
  class PropertyPrototype < Spree::Base
    self.table_name = 'spree_properties_prototypes'

    belongs_to :prototype, class_name: 'Spree::Prototype'
    belongs_to :property, class_name: 'Spree::Property'
  end
end
