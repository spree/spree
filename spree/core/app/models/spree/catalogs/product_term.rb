module Spree
  module Catalogs
    # One product's quantity terms under a catalog, as the dashboard edits
    # them: the rows are per variant, but a merchant states a minimum for a
    # product.
    #
    # +mixed+ marks a product whose variants carry different terms — reachable
    # through the API, which writes per variant, and reported honestly rather
    # than by picking one variant's pair and calling it the product's.
    class ProductTerm
      include ActiveModel::Model

      attr_accessor :product, :rules

      # @return [Integer, nil] nil when the variants disagree or none states one
      def minimum_order_quantity
        single(:minimum_order_quantity)
      end

      # @return [Integer, nil]
      def order_multiple
        single(:order_multiple)
      end

      # @return [Boolean] true when the product's variants disagree
      def mixed?
        %i[minimum_order_quantity order_multiple].any? { |field| values(field).uniq.many? } ||
          Array(rules).size != product.variants.count
      end

      private

      def values(field)
        Array(rules).map { |rule| rule.public_send(field) }
      end

      def single(field)
        distinct = values(field).uniq
        distinct.one? ? distinct.first : nil
      end
    end
  end
end
