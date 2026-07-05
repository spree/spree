module Spree
  module Metafields
    class Number < Spree::Metafield
      validates :value, numericality: true

      def serialize_value
        value.to_d
      end

      def csv_value
        value.to_d.to_s
      end
    end
  end
end
