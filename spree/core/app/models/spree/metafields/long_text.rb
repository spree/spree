module Spree
  module Metafields
    class LongText < Spree::Metafield
      normalizes :value, with: ->(value) { value.to_s.strip }
    end
  end
end
