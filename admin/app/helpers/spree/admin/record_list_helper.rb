module Spree
  module Admin
    module RecordListHelper
      # Main helper to render a record list
      # @param collection [ActiveRecord::Relation] the collection to render
      # @param list_key [Symbol] the record list registry key (e.g., :products)
      # @param options [Hash] additional options
      # @option options [Boolean] :bulk_operations enable bulk operations
      # @option options [Boolean] :sortable enable drag-and-drop sorting
      # @option options [String] :frame_name custom turbo frame name
      # @return [String] rendered HTML
      def render_record_list(collection, list_key, **options)
        record_list = Spree.admin.record_lists.get(list_key)
        selected_columns = session_selected_columns(list_key)

        render 'spree/admin/record_lists/record_list',
               collection: collection,
               record_list: record_list,
               list_key: list_key,
               selected_columns: selected_columns,
               **options
      end

      # Get selected column keys from session
      # @param list_key [Symbol] record list key
      # @return [Array<Symbol>, nil]
      def session_selected_columns(list_key)
        keys = session["record_list_columns_#{list_key}"]
        return nil if keys.blank?

        keys.split(',').map(&:to_sym)
      end

      # Save selected columns to session
      # @param list_key [Symbol] record list key
      # @param column_keys [Array<Symbol>] selected column keys
      def save_selected_columns(list_key, column_keys)
        session["record_list_columns_#{list_key}"] = column_keys.join(',')
      end

      # Render a single column value based on its type
      # @param record [Object] the record
      # @param column [Spree::Admin::RecordList::Column] the column definition
      # @param record_list [Spree::Admin::RecordList] the record list
      # @return [String] rendered HTML
      def render_column_value(record, column, record_list)
        value = column.resolve_value(record, self)

        case column.type
        when :currency
          render_currency_column(value, column)
        when :date
          render_date_column(value, column)
        when :datetime
          render_datetime_column(value, column)
        when :status
          render_status_column(value, column)
        when :boolean
          render_boolean_column(value, column)
        when :link
          render_link_column(record, value, column)
        when :image
          render_image_column(record, value, column)
        when :custom
          render partial: column.partial, locals: { record: record, column: column, value: value }
        when :association
          render_association_column(value, column)
        else
          render_string_column(value, column)
        end
      end

      # Render currency column
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_currency_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        if value.respond_to?(:display_amount)
          value.display_amount
        else
          Spree::Money.new(value, currency: current_currency).to_html
        end
      end

      # Render date column
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_date_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        if column.format.present? && respond_to?(column.format)
          send(column.format, value)
        else
          l(value.to_date, format: :short)
        end
      end

      # Render datetime column
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_datetime_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        if column.format.present? && respond_to?(column.format)
          send(column.format, value)
        else
          local_time_ago(value)
        end
      end

      # Render status column as badge
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_status_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        css_class = case value.to_s
                    when 'active', 'complete', 'completed', 'paid', 'shipped', 'available'
                      'badge-active'
                    when 'draft', 'pending', 'processing', 'ready'
                      'badge-warning'
                    when 'archived', 'canceled', 'cancelled', 'failed', 'void', 'inactive'
                      'badge-inactive'
                    else
                      'badge-secondary'
                    end

        content_tag(:span, Spree.t(value, scope: column.key, default: value.to_s.humanize), class: "badge #{css_class}")
      end

      # Render boolean column
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_boolean_column(value, column)
        active_badge(value)
      end

      # Render link column
      # @param record [Object] the record
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_link_column(record, value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        h(value.to_s.truncate(100))
      end

      # Render image column
      # @param record [Object] the record
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_image_column(record, value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        if value.respond_to?(:attached?) && value.attached?
          image_tag url_for(value.variant(resize_to_limit: [50, 50])), class: 'rounded', loading: 'lazy'
        elsif value.is_a?(String) && value.present?
          image_tag value, class: 'rounded', style: 'max-width: 50px; max-height: 50px;', loading: 'lazy'
        else
          content_tag(:span, '-', class: 'text-gray-400')
        end
      end

      # Render string column
      # @param value [Object] the value
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_string_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        if column.format.present? && respond_to?(column.format)
          send(column.format, value)
        else
          h(value.to_s.truncate(100))
        end
      end

      # Render association column (e.g., taxons, tags)
      # @param value [Object] the value (expected to be a string from method lambda)
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def render_association_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        h(value.to_s.truncate(100))
      end

      # Render sort dropdown for sortable columns
      # @param record_list [Spree::Admin::RecordList] the record list
      # @param current_sort [String, nil] current sort value (e.g., "name asc")
      # @return [String]
      def record_list_sort_dropdown(record_list, current_sort)
        sortable = record_list.sortable_columns
        return '' if sortable.empty?

        current_label = find_sort_label(sortable, current_sort)

        dropdown(portal: false) do
          toggle = dropdown_toggle(class: 'btn-light btn-sm flex items-center gap-1') do
            safe_join([
              icon('arrows-sort', class: 'w-4 h-4'),
              content_tag(:span, current_label),
              icon('chevron-down', class: 'w-3 h-3')
            ])
          end

          menu = dropdown_menu(class: 'min-w-[200px]') do
            items = sortable.flat_map do |column|
              [
                sort_dropdown_item(column, 'asc', current_sort),
                sort_dropdown_item(column, 'desc', current_sort)
              ]
            end
            safe_join(items)
          end

          safe_join([toggle, menu])
        end
      end

      # Get column header CSS class
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def column_header_class(column)
        classes = []
        classes << "text-#{column.align}" if column.align != :left
        classes << "w-#{column.width}" if column.width.present?
        classes.join(' ')
      end

      # Get column cell CSS class
      # @param column [Spree::Admin::RecordList::Column] column definition
      # @return [String]
      def column_cell_class(column)
        classes = []
        classes << "text-#{column.align}" if column.align != :left
        classes.join(' ')
      end

      # Build query builder fields JSON for Stimulus controller
      # @param record_list [Spree::Admin::RecordList] the record list
      # @return [String] JSON string
      def query_builder_fields_json(record_list)
        query_builder = Spree::Admin::RecordList::QueryBuilder.new(record_list)
        query_builder.available_fields.to_json
      end

      # Build available operators JSON for Stimulus controller
      # @return [String] JSON string
      def query_builder_operators_json
        Spree::Admin::RecordList::Filter.operators_for_select.to_json
      end

      private

      def find_sort_label(sortable, current_sort)
        return Spree.t('admin.record_lists.sort_by') if current_sort.blank?

        field, direction = current_sort.split(' ')
        column = sortable.find { |c| c.ransack_attribute == field }

        if column
          dir_label = direction == 'asc' ? 'ASC' : 'DESC'
          "#{column.resolve_label} (#{dir_label})"
        else
          Spree.t('admin.record_lists.sort_by')
        end
      end

      def sort_dropdown_item(column, direction, current_sort)
        sort_value = "#{column.ransack_attribute} #{direction}"
        is_active = current_sort == sort_value
        dir_label = direction == 'asc' ? 'ASC' : 'DESC'
        label = "#{column.resolve_label} (#{dir_label})"

        # Convert params[:q] to a regular hash to avoid unpermitted parameters error
        current_q = params[:q].respond_to?(:to_unsafe_h) ? params[:q].to_unsafe_h : (params[:q] || {})

        link_to label,
                url_for(q: current_q.merge(s: sort_value)),
                class: "dropdown-item #{'active' if is_active}",
                data: { turbo_action: 'advance' }
      end
    end
  end
end
