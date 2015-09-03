module Spree
  class PropertyPrototype < Spree::Base
    belongs_to :prototype
    belongs_to :property
  end
end
