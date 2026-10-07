module Spree
  module Exports
    class Products < Spree::Export
      # to avoid N+1 queries
      def scope_includes
        includes = [:tax_category, :option_types, :categories, { variants: variant_includes }]
        includes << { custom_fields: :custom_field_definition }
        includes
      end

      def variant_includes
        [:images, :prices, { stock_levels: :stock_location, option_values: [:option_type] }]
      end

      def multi_line_csv?
        true
      end

      # The seller scopes which locations the inventory columns cover; their
      # default, worked out once per export, carries the full row's stock.
      def to_csv_options
        @to_csv_options ||= {
          seller: seller,
          default_stock_location: Spree::StockLocation.owned_by(store_id: store.id, seller_id: seller&.id).active.order_default.first || store.default_stock_location
        }
      end

      # when doing full product export, we want to exclude archived products
      def scope
        if search_params.nil?
          super.where.not(status: 'archived')
        else
          super
        end
      end

      def csv_headers
        headers = Spree::CSV::ProductVariantPresenter::CSV_HEADERS.dup
        headers += custom_fields_headers
        @csv_headers ||= headers
      end
    end
  end
end
