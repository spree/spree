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
        [:images, :prices, :stock_levels, :stock_locations, { option_values: [:option_type] }]
      end

      def multi_line_csv?
        true
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
