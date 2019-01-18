module Spree
  module Orders
    class Sort
      attr_reader :scope, :sort

      def initialize(scope, params)
        @scope = scope
        @sort = params[:sort]
      end

      def call
        orders = completed_at(scope)

        orders
      end

      private

      def desc_order
        @desc_order ||= String(sort)[0] == '-'
      end

      def sort_field
        @sort_field ||= desc_order ? sort[1..-1] : sort
      end

      def order_direction
        desc_order ? :asc : :desc
      end

      def completed_at?
        sort_field.eql?('completed_at')
      end

      def completed_at(orders)
        return orders unless completed_at?

        orders.order(completed_at: order_direction)
      end
    end
  end
end
