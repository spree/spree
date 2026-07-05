module Spree
  module Api
    module V3
      class FiltersAggregator
        # @param scope [ActiveRecord::Relation] Base product scope (fully filtered, including option values)
        # @param currency [String] Currency for price range
        # @param category [Spree::Category, nil] Optional category for default_sort and category filtering context
        # @param option_value_ids [Array<String>] Currently selected option value prefixed IDs (for disjunctive facet counts)
        # @param scope_before_options [ActiveRecord::Relation] Scope before option value filters (for disjunctive counts)
        def initialize(scope:, currency:, category: nil, option_value_ids: [], scope_before_options: nil)
          @scope = scope
          @currency = currency
          @category = category
          @option_value_ids = option_value_ids
          @scope_before_options = scope_before_options || scope
        end

        def call
          {
            filters: build_filters,
            sort_options: sort_options,
            default_sort: to_api_sort(@category&.sort_order || 'manual'),
            total_count: @scope.distinct.count
          }
        end

        private

        def build_filters
          [
            price_filter,
            availability_filter,
            *option_type_filters,
            category_filter
          ].compact
        end

        def sort_options
          Spree::Taxon::SORT_ORDERS.map { |id| { id: to_api_sort(id) } }
        end

        # Converts internal sort format ('price asc') to API format ('price', '-price')
        def to_api_sort(sort_value)
          return sort_value unless sort_value.include?(' ')

          field, direction = sort_value.split(' ', 2)
          direction == 'desc' ? "-#{field}" : field
        end


        def price_filter
          # Remove ordering to avoid PostgreSQL DISTINCT + ORDER BY conflicts
          prices = Spree::Price.for_products(@scope.reorder(''), @currency)
          min = prices.minimum(:amount)
          max = prices.maximum(:amount)
          return nil if min.nil? || max.nil?

          {
            id: 'price',
            type: 'price_range',
            min: min.to_f,
            max: max.to_f,
            currency: @currency
          }
        end

        def availability_filter
          in_stock_count = @scope.in_stock.distinct.count
          out_of_stock_count = @scope.out_of_stock.distinct.count

          return nil if in_stock_count.zero? && out_of_stock_count.zero?

          {
            id: 'availability',
            type: 'availability',
            options: [
              { id: 'in_stock', count: in_stock_count },
              { id: 'out_of_stock', count: out_of_stock_count }
            ]
          }
        end

        def option_type_filters
          option_types = Spree::OptionType.filterable.order(:position).to_a
          return [] if option_types.empty?

          type_ids = option_types.map(&:id)

          # Pluck only the columns we need — avoids instantiating thousands of AR models.
          # Force default locale so Mobility returns column values (not translations);
          # translated labels are overlaid separately via load_option_value_translations.
          ov_rows = Mobility.with_locale(I18n.default_locale) do
            Spree::OptionValue
              .where(option_type_id: type_ids)
              .order(:position)
              .pluck(:id, :option_type_id, :name, :presentation, :position, :color_code)
          end
          return [] if ov_rows.empty?

          all_ov_ids = ov_rows.map(&:first)

          # Batch-load image attachment existence (single query)
          ov_ids_with_images = ActiveStorage::Attachment
            .where(record_type: 'Spree::OptionValue', name: 'image', record_id: all_ov_ids)
            .pluck(:record_id)
            .to_set

          # Batch-load translations for current locale (single query, skip for default locale with column_fallback)
          ov_translations = load_option_value_translations(all_ov_ids)

          # Group rows by option type
          ov_rows_by_type = ov_rows.group_by { |row| row[1] }

          # Batch counts
          if grouped_selected_options.empty?
            counts = batch_option_value_counts(@scope_before_options, all_ov_ids)
          else
            scope_groups = option_types.group_by { |ot| disjunctive_scope_for(ot) }
            counts = {}
            scope_groups.each do |scope, types|
              ov_ids = types.flat_map { |t| ov_rows_by_type[t.id]&.map(&:first) || [] }
              counts.merge!(batch_option_value_counts(scope, ov_ids))
            end
          end

          build_option_type_results(option_types, ov_rows_by_type, counts, ov_ids_with_images, ov_translations)
        end

        # Single grouped COUNT query for all option value IDs against a product scope.
        # Returns { option_value_id => product_count }
        def batch_option_value_counts(product_scope, option_value_ids)
          return {} if option_value_ids.empty?

          ovv_table = Spree::OptionValueVariant.table_name
          var_table = Spree::Variant.table_name

          Spree::OptionValueVariant
            .joins("INNER JOIN #{var_table} ON #{var_table}.id = #{ovv_table}.variant_id AND #{var_table}.deleted_at IS NULL")
            .where(var_table => { product_id: product_scope.reorder('').select(:id) })
            .where(ovv_table => { option_value_id: option_value_ids })
            .group("#{ovv_table}.option_value_id")
            .distinct
            .count("#{var_table}.product_id")
        end

        # Load translated presentations for option values.
        # Returns { option_value_id => translated_presentation } or empty hash when using the default locale.
        def load_option_value_translations(ov_ids)
          locale = Spree::Current.locale || I18n.locale.to_s
          return {} if locale.to_s == I18n.default_locale.to_s

          Spree::OptionValue::Translation
            .where(spree_option_value_id: ov_ids, locale: locale)
            .pluck(:spree_option_value_id, :presentation)
            .to_h
        end

        def build_option_type_results(option_types, ov_rows_by_type, counts, ov_ids_with_images, ov_translations)
          # Pre-load image URLs for option values that have images (single batch)
          image_urls = load_image_urls(ov_ids_with_images)

          option_types.filter_map do |option_type|
            rows = ov_rows_by_type[option_type.id]
            next if rows.blank?

            # rows: [id, option_type_id, name, presentation, position, color_code]
            options = rows.filter_map do |id, _, name, presentation, position, color_code|
              count = counts[id] || 0
              next if count.zero?

              label = ov_translations[id] || presentation

              {
                id: encode_prefixed_id(:optval, id),
                name: name,
                label: label,
                position: position,
                color_code: color_code,
                image_url: image_urls[id],
                count: count
              }
            end
            next if options.empty?

            {
              id: option_type.prefixed_id,
              type: 'option',
              name: option_type.name,
              label: option_type.label,
              kind: option_type.kind,
              options: options
            }
          end
        end

        # Load image URLs for option values that have images.
        # Only instantiates AR models for the small subset with images (typically color swatches).
        def load_image_urls(ov_ids_with_images)
          return {} if ov_ids_with_images.empty?

          Spree::OptionValue.where(id: ov_ids_with_images.to_a)
            .includes(image_attachment: :blob)
            .each_with_object({}) do |ov, urls|
              urls[ov.id] = Rails.application.routes.url_helpers.cdn_image_url(ov.image)
            end
        end

        def encode_prefixed_id(prefix, id)
          "#{prefix}_#{Spree::PrefixedId::SQIDS.encode([id])}"
        end

        # Returns the scope with all option type filters EXCEPT the given one applied.
        # This gives disjunctive counts: selecting Blue still shows Red's true count.
        def disjunctive_scope_for(option_type)
          return @scope_before_options if grouped_selected_options.empty?

          other_groups = grouped_selected_options.except(option_type.id)

          # If this type has selections but no other types do, use scope before any option filters
          return @scope_before_options if other_groups.empty?

          # Rebuild: start from scope before options, apply only other option types
          scope = @scope_before_options
          other_groups.each_value do |ov_ids|
            matching = Spree::Variant.where(deleted_at: nil)
                                     .joins(:option_value_variants)
                                     .where(Spree::OptionValueVariant.table_name => { option_value_id: ov_ids })
                                     .select(:product_id)
            scope = scope.where(id: matching)
          end
          scope
        end

        # Group selected option value IDs by option type (cached, single query)
        def grouped_selected_options
          @grouped_selected_options ||= begin
            return {} if @option_value_ids.blank?

            decoded = @option_value_ids.filter_map { |id| Spree::OptionValue.decode_prefixed_id(id) }
            return {} if decoded.empty?

            Spree::OptionValue.where(id: decoded).group_by(&:option_type_id).transform_values { |ovs| ovs.map(&:id) }
          end
        end

        def category_filter
          return nil if @category.nil?

          # Get child categories at the next depth level
          child_categories = @category.children.order(:lft).select do |child|
            # Only include categories that have products in the current scope
            @scope.in_category(child).exists?
          end

          return nil if child_categories.empty?

          {
            id: 'categories',
            type: 'category',
            options: child_categories.map { |c| category_option_data(c) }
          }
        end

        def category_option_data(category)
          count = @scope.in_category(category).distinct.count

          {
            id: category.prefixed_id,
            name: category.name,
            permalink: category.permalink,
            count: count
          }
        end
      end
    end
  end
end
