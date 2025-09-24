module Spree
  module MetafieldDefinitions
    class LongText < Spree::MetafieldDefinition
      normalizes :value, with: ->(value) { value.to_s.strip }
    end
  end
end
