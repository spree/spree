module Spree
  module Metafields
    class LongText < Spree::Metafield
      normalizes :value, with: ->(value) { value.to_s.strip }

      def self.searchable?
        true
      end
    end
  end
end
