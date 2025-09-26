module Spree
  module Metafields
    class Number < Spree::Metafield
      validates :value, numericality: true

      # we need to typecast here, as value column is a text in the database
      def value
        BigDecimal(attributes['value']) if attributes['value'].present?
      end
    end
  end
end
