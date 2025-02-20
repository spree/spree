module Spree
  module Exports
    class Products < Spree::Export
      # to avoid N+1 queries
      def scope_includes
        [:tax_category, :master, { taxons: :taxonomy }, { product_properties: [:property] }, { variants_including_master: variant_includes }]
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
        (
          Spree::CSV::ProductVariantPresenter::CSV_HEADERS +
          images_headers +
          options_headers +
          categories_headers +
          properties_headers
        ).flatten
      end

      def images_headers
        variant_ids = store.variants.where(product_id: records_to_export.ids).ids
        max_images_count = Spree::Image.
                           where(viewable_id: variant_ids, viewable_type: 'Spree::Variant').
                           group(:viewable_id).
                           select("COUNT(#{Spree::Image.table_name}.viewable_id) AS count_viewable_id").
                           map(&:count_viewable_id).
                           max

        [max_images_count || 0, 3].max.times.map { |n| ["image#{n + 1}_src"] }
      end

      def categories_headers
        categories_taxonomy = store.taxonomies.find_by(name: Spree.t(:taxonomy_categories_name))
        max_categories_count = Spree::Classification.
                               joins(:taxon).
                               where(product_id: records_to_export.ids).
                               where(taxon: { taxonomy_id: categories_taxonomy.id }).
                               group(:product_id).
                               count(:product_id).
                               values.
                               max

        [max_categories_count || 0, 3].max.times.map { |n| ["category#{n + 1}"] }
      end

      def options_headers
        max_options_count = Spree::ProductOptionType.
                            where(product_id: records_to_export.ids).
                            group(:product_id).
                            count(:product_id).
                            values.
                            max

        [max_options_count || 0, 3].max.times.map { |n| ["option#{n + 1}_name", "option#{n + 1}_value"] }
      end

      def properties_headers
        @properties_headers ||= Spree::Property.order(:position).count.times.flat_map { |n| ["property#{n + 1}_name", "property#{n + 1}_value"] }
      end
    end
  end
end
