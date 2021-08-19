module Spree
  module Products
    class Sort < ::Spree::BaseSorter
      def initialize(scope, current_currency, params = {}, allowed_sort_attributes = [])
        super(scope, params, allowed_sort_attributes)
        @currency = params[:currency] || current_currency
      end

      def call
        products = by_param_attribute(scope)
        products = by_price(products)
        products = by_sku(products)

        products.distinct
      end

      private

      attr_reader :sort, :scope, :currency, :allowed_sort_attributes

      def price?
        sort_field == 'price'
      end

      def by_price(scope)
        return scope unless price?

        scope.joins(master: :prices).
          select("#{Spree::Product.table_name}.*, #{Spree::Price.table_name}.amount").
          distinct.
          where(spree_prices: { currency: currency }).
          order("#{Spree::Price.table_name}.amount #{order_direction}")
      end

      def sku?
        sort_field == 'sku'
      end

      def by_sku(scope)
        return scope unless sku?

        scope.joins(:master).
          select("#{Spree::Product.table_name}.*, #{Spree::Variant.table_name}.sku").
          where(Spree::Variant.table_name.to_s => { is_master: true }).
          order("#{Spree::Variant.table_name}.sku #{order_direction}")
      end
    end
  end
end
