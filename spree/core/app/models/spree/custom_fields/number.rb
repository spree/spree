module Spree
  module CustomFields
    class Number < Spree::CustomField
      validates :value, numericality: true

      def self.searchable?
        true
      end

      def self.sortable?
        true
      end

      def serialize_value
        value.to_d
      end

      def csv_value
        value.to_d.to_s
      end
    end
  end
end
