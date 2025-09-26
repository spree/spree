module Spree
  module Metafields
    class Boolean < Spree::Metafield
      normalizes :value, with: lambda(&:to_b)
    end
  end
end
