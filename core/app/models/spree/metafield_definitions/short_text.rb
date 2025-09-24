module Spree
  module MetafieldDefinitions
    class ShortText < Spree::MetafieldDefinition
      normalizes :value, with: ->(value) { value.to_s.strip }
    end
  end
end
