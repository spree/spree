module Spree
  module Metafields
    class ShortText < Spree::Metafield
      normalizes :value, with: ->(value) { value.to_s.strip }
    end
  end
end
