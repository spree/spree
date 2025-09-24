module Spree
  module MetafieldDefinitions
    class Boolean < Spree::MetafieldDefinition
      normalizes :value, with: lambda(&:to_b)
    end
  end
end
