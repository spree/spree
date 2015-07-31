module Spree
  class PropertyPrototype < Spree::Base
    belongs_to :prototype, class_name: 'Spree::Prototype'
    belongs_to :property, class_name: 'Spree::Property'
  end
end
