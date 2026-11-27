module Spree
  module CustomFields
    class LongText < Spree::CustomField
      def self.storefront_writable?
        true
      end

      include TextRules

      normalizes :value, with: ->(value) { value.to_s.strip }

      def self.searchable?
        true
      end
    end
  end
end
