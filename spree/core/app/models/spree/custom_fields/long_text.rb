module Spree
  module CustomFields
    class LongText < Spree::CustomField
      normalizes :value, with: ->(value) { value.to_s.strip }

      def self.searchable?
        true
      end
    end
  end
end
