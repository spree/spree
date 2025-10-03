module Spree
  module Metafields
    class Boolean < Spree::Metafield
      normalizes :value, with: lambda(&:to_b)

      def csv_value
        value.to_b ? Spree.t(:say_yes) : Spree.t(:say_no)
      end
    end
  end
end
