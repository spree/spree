module Spree
  module Products
    class Find
      def initialize(scope:, params:, current_currency:)
        @scope = scope

        @ids              = String(params.dig(:filter, :ids)).split(',')
        @skus             = String(params.dig(:filter, :skus)).split(',')
        @price            = String(params.dig(:filter, :price)).split(',').map(&:to_f)
        @currency         = params[:currency] || current_currency
        @taxons           = taxon_ids(params.dig(:filter, :taxons))
        @name             = params.dig(:filter, :name)
        @options          = params.dig(:filter, :options).try(:to_unsafe_hash)
        @option_value_ids = params.dig(:filter, :option_value_ids)
        @sort_by          = params.dig(:sort_by)
        @deleted          = params.dig(:filter, :show_deleted)
        @discontinued     = params.dig(:filter, :show_discontinued)
      end

      def execute
        products = by_ids(scope)
        products = by_skus(products)
        products = by_price(products)
        products = by_taxons(products)
        products = by_name(products)
        products = by_options(products)
        products = by_option_value_ids(products)
        products = include_deleted(products)
        products = include_discontinued(products)
        products = ordered(products)

        products.distinct
      end

      private

      attr_reader :ids, :skus, :price, :currency, :taxons, :name, :options, :option_value_ids, :scope, :sort_by, :deleted, :discontinued

      def ids?
        ids.present?
      end

      def skus?
        skus.present?
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

      def option_value_ids?
        option_value_ids.present?
      end

      def sort_by?
        sort_by.present?
      end

      def name_matcher
        Spree::Product.arel_table[:name].matches("%#{name}%")
      end

      def by_ids(products)
        return products unless ids?

        products.where(id: ids)
      end

      def by_skus(products)
        return products unless skus?

        products.joins(:variants_including_master).where(spree_variants: { sku: skus })
      end

      def by_price(products)
        return products unless price?

        products.joins(master: :default_price).
          where(
            spree_prices: {
              amount: price.min..price.max,
              currency: currency
            }
          )
      end

      def by_taxons(products)
        return products unless taxons?

        products.joins(:taxons).where(spree_taxons: { id: taxons })
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

      def by_option_value_ids(products)
        return products unless option_value_ids?

        product_ids = Spree::Product.
                      joins(variants: :option_values).
                      where(spree_option_values: { id: option_value_ids }).
                      group("#{Spree::Product.table_name}.id, #{Spree::Variant.table_name}.id").
                      having('COUNT(spree_option_values.option_type_id) = ?', option_types_count(option_value_ids)).
                      distinct.
                      ids

        products.where(id: product_ids)
      end

      def option_types_count(option_value_ids)
        Spree::OptionValue.
          where(id: option_value_ids).
          distinct.
          count(:option_type_id)
      end

      def ordered(products)
        return products unless sort_by?

        case sort_by
        when 'default'
          products
        when 'newest-first'
          products.order(available_on: :desc)
        when 'price-high-to-low'
          products.select('spree_products.*, spree_prices.amount').reorder('').send(:descend_by_master_price)
        when 'price-low-to-high'
          products.select('spree_products.*, spree_prices.amount').reorder('').send(:ascend_by_master_price)
        end
      end

      def include_deleted(products)
        deleted ? products.with_deleted : products.not_deleted
      end

      def include_discontinued(products)
        discontinued ? products : products.available
      end

      def taxon_ids(taxon_id)
        return unless (taxon = Spree::Taxon.find_by(id: taxon_id))

        taxon.self_and_descendants.ids.map(&:to_s)
      end
    end
  end
end
