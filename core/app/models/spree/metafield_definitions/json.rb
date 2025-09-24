module Spree
  module MetafieldDefinitions
    class Json < Spree::MetafieldDefinition
      normalizes :value, with: ->(value) { JSON.parse(value) }
    end
  end
end
