module Spree
  module Exports
    class Products < Spree::Export
      # to avoid N+1 queries
      def scope_includes
        includes = [:tax_category, :master, { taxons: :taxonomy }, { variants_including_master: variant_includes }]
        includes << { product_properties: [:property] } if Spree::Config[:product_properties_enabled]
        includes << { metafields: :metafield_definition }
        includes
      end

      def variant_includes
        [:images, :prices, :stock_items, { option_values: [:option_type] }]
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
        headers += properties_headers if Spree::Config[:product_properties_enabled]
        headers += metafields_headers
        @csv_headers ||= headers
      end

      def properties_headers
        @properties_headers ||= Spree::Property.order(:position).count.times.flat_map { |n| ["property#{n + 1}_name", "property#{n + 1}_value"] }
      end
    end
  end
end
