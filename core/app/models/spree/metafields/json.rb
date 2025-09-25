module Spree
  module Metafields
    class Json < Spree::Metafield
      normalizes :value, with: ->(value) { value.is_a?(String) ? JSON.parse(value) : value }
    end
  end
end
