module Spree
  module Metafields
    class Boolean < Spree::Metafield
      normalizes :value, with: ->(value) { value.to_b.to_s }

      def csv_value
        value.to_b ? Spree.t(:say_yes) : Spree.t(:say_no)
      end

      def serialize_value
        value.to_b
      end
    end
  end
end
