module Spree
  module Products
    class Sort
      def initialize(scope, params, current_currency)
        @scope    = scope
        @sort     = params[:sort]
        @filter   = params[:filter]
        @currency = params[:currency] || current_currency
      end

      def call
        products = updated_at(scope)
        products = price(products)
        products = available(products)

        products
      end

      private

      attr_reader :sort, :scope, :currency

      def desc_order
        @desc_order ||= String(sort)[0] == '-'
      end

      def sort_field
        @sort_field ||= desc_order ? sort[1..-1] : sort
      end

      def updated_at?
        sort_field == 'updated_at'
      end

      def price?
        sort_field == 'price'
      end

      def order_direction
        desc_order ? :desc : :asc
      end

      def updated_at(products)
        return products unless updated_at?

        products.order(updated_at: order_direction)
      end

      def price(products)
        return products unless price?

        products.joins(master: :prices).
          select("#{Spree::Product.table_name}.*, #{Spree::Price.table_name}.amount").
          distinct.
          where(spree_prices: { currency: currency }).
          order("#{Spree::Price.table_name}.amount #{order_direction}")
      end

      def available(products)
        if @filter
          if @filter[:show_discontinued]
            return products
          end
        end

        products.available(Time.current)
      end
    end
  end
end
