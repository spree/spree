module Spree
  module CustomFields
    class ShortText < Spree::CustomField
      normalizes :value, with: ->(value) { value.to_s.strip }

      def self.searchable?
        true
      end

      def self.sortable?
        true
      end
    end
  end
end
