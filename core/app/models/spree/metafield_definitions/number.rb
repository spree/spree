module Spree
  module MetafieldDefinitions
    class Number < Spree::MetafieldDefinition
      validates :value, numericality: true
    end
  end
end
