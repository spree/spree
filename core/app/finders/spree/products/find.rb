module Spree
  module Products
    class Find
      def initialize(scope:, params:, current_currency:)
        @scope = scope

        @ids      = String(params.dig(:filter, :ids)).split(',')
        @price    = String(params.dig(:filter, :price)).split(',')
        @currency = params[:currency] || current_currency
        @taxons   = String(params.dig(:filter, :taxons)).split(',')
        @name     = params.dig(:filter, :name)
        @options  = params.dig(:filter, :options).try(:to_unsafe_hash)
      end

      def execute
        products = by_ids(scope)
        products = by_price(products)
        products = by_taxons(products)
        products = by_name(products)
        products = by_options(products)

        products
      end

      private

      attr_reader :ids, :price, :currency, :taxons, :name, :options, :scope

      def ids?
        ids.present?
      end

      def price?
        price.present?
      end

      def taxons?
        taxons.present?
      end

      def name?
        name.present?
      end

      def options?
        options.present?
      end

      def name_matcher
        Spree::Product.arel_table[:name].matches("%#{name}%")
      end

      def by_ids(products)
        return products unless ids?

        products.where(id: ids)
      end

      def by_price(products)
        return products unless price?

        products.joins(master: :default_price).
          distinct.
          where(
            spree_prices: {
              amount: price.min..price.max,
              currency: currency
            }
          )
      end

      def by_taxons(products)
        return products unless taxons?

        products.joins(:taxons).distinct.where(spree_taxons: { id: taxons })
      end

      def by_name(products)
        return products unless name?

        products.where(name_matcher)
      end

      def by_options(products)
        return products unless options?

        options.map do |key, value|
          products.with_option_value(key, value)
        end.inject(:&)
      end
    end
  end
end
