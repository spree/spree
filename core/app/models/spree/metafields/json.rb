module Spree
  module Metafields
    class Json < Spree::Metafield
      normalizes :value, with: ->(value) { JSON.parse(value) }
    end
  end
end
