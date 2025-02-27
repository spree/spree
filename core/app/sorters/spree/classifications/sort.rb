module Spree
  module Classifications
    class Sort < ::Spree::BaseSorter
      def initialize(scope, current_currency, params = {}, allowed_sort_attributes = [])
        super(scope.reorder(''), params, allowed_sort_attributes)

        @currency = params[:currency] || current_currency
      end

      def call
        classifications = by_manual(scope)
        classifications = by_best_selling(classifications)
        classifications = by_param_attributes(classifications)
        by_price(classifications)
      end

      private

      attr_reader :sort, :scope, :currency, :allowed_sort_attributes

      def by_manual(scope)
        return scope unless sort_by?('manual')

        scope.order(position: :asc)
      end

      def by_best_selling(scope)
        return scope unless (value = sort_by?('best_selling'))

        scope.by_best_selling(value[1])
      end

      def by_param_attributes(scope)
        return scope if sort.empty?

        sort.each do |value, order|
          next if value.blank? || Spree::Product.column_names.exclude?(value)

          table_name = if Spree.use_translations?
                         translatable_fields = Spree::Product::TRANSLATABLE_FIELDS
                         value.to_sym.in?(translatable_fields) ? Spree::Product.translation_table_alias : Spree::Product.table_name
                       else
                         Spree::Product.table_name
                       end

          scope = scope.order("#{table_name}.#{value}": order)
        end

        scope
      end

      def by_price(scope)
        return scope unless (value = sort_by?('price'))

        scope.joins(product: { variants_including_master: :prices }).
          select("#{Spree::Classification.table_name}.*, min(#{Spree::Price.table_name}.amount)").
          distinct.
          where(spree_prices: { currency: currency }).
          order("min(#{Spree::Price.table_name}.amount) #{value[1]}").
          group("#{Spree::Classification.table_name}.id")
      end

      def sort_by?(field)
        sort.detect { |s| s[0] == field }
      end
    end
  end
end
