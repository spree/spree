module Spree
  module Metafields
    class Number < Spree::Metafield
      validates :value, numericality: true
    end
  end
end
