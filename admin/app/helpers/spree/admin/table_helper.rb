module Spree
  module Admin
    module TableHelper
      # Main helper to render a table
      # @param collection [ActiveRecord::Relation] the collection to render
      # @param table_key [Symbol] the table registry key (e.g., :products)
      # @param options [Hash] additional options
      # @option options [Boolean] :bulk_operations enable bulk operations
      # @option options [Boolean] :sortable enable drag-and-drop sorting
      # @option options [String] :frame_name custom turbo frame name
      # @option options [Class] :export_type export class (e.g., Spree::Exports::Customers)
      # @return [String] rendered HTML
      def render_table(collection, table_key, **options)
        table = Spree.admin.tables.get(table_key)
        selected_columns = session_selected_columns(table_key)

        render 'spree/admin/tables/table',
               collection: collection,
               table: table,
               table_key: table_key,
               selected_columns: selected_columns,
               **options
      end

      # Get selected column keys from session
      # @param table_key [Symbol] table key
      # @return [Array<Symbol>, nil]
      def session_selected_columns(table_key)
        keys = session["table_columns_#{table_key}"]
        return nil if keys.blank?

        keys.split(',').map(&:to_sym)
      end

      # Save selected columns to session
      # @param table_key [Symbol] table key
      # @param column_keys [Array<Symbol>] selected column keys
      def save_selected_columns(table_key, column_keys)
        session["table_columns_#{table_key}"] = column_keys.join(',')
      end

      # Render a single column value based on its type
      # @param record [Object] the record
      # @param column [Spree::Admin::Table::Column] the column definition
      # @param table [Spree::Admin::Table] the table
      # @return [String] rendered HTML
      def render_column_value(record, column, table)
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
          extra_locals = column.partial_locals.is_a?(Proc) ? column.partial_locals.call(record) : column.partial_locals
          locals = { record: record, column: column, value: value }.merge(extra_locals)
          render partial: column.partial, locals: locals
        when :association
          render_association_column(value, column)
        else
          render_string_column(value, column)
        end
      end

      # Render currency column
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
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
      # @param column [Spree::Admin::Table::Column] column definition
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
      # @param column [Spree::Admin::Table::Column] column definition
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
      # @param column [Spree::Admin::Table::Column] column definition
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
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_boolean_column(value, column)
        active_badge(value)
      end

      # Render link column
      # @param record [Object] the record
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_link_column(record, value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        h(value.to_s.truncate(100))
      end

      # Render image column
      # @param record [Object] the record
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
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
      # @param column [Spree::Admin::Table::Column] column definition
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
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_association_column(value, column)
        return content_tag(:span, '-', class: 'text-gray-400') if value.blank?

        h(value.to_s.truncate(100))
      end

      # Render sort dropdown for sortable columns
      # @param table [Spree::Admin::Table] the table
      # @param current_sort [String, nil] current sort value (e.g., "name asc")
      # @return [String]
      def table_sort_dropdown(table, current_sort)
        sortable = table.sortable_columns
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
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def column_header_class(column)
        classes = []
        classes << "text-#{column.align}" if column.align != :left
        classes << "w-#{column.width}" if column.width.present?
        classes.join(' ')
      end

      # Get column cell CSS class
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def column_cell_class(column)
        classes = []
        classes << "text-#{column.align}" if column.align != :left
        classes.join(' ')
      end

      # Build query builder fields JSON for Stimulus controller
      # @param table [Spree::Admin::Table] the table
      # @return [String] JSON string
      def query_builder_fields_json(table)
        query_builder = Spree::Admin::Table::QueryBuilder.new(table)
        query_builder.available_fields.to_json
      end

      # Build available operators JSON for Stimulus controller
      # @return [String] JSON string
      def query_builder_operators_json
        Spree::Admin::Table::Filter.operators_for_select.to_json
      end

      # Count the number of applied filters from query_state parameter
      # @param query_state [String] JSON string of query state
      # @return [Integer] total number of filters applied
      def count_applied_filters(query_state)
        return 0 if query_state.blank? || query_state == '{}'

        begin
          state = JSON.parse(query_state)
          count_filters_in_state(state)
        rescue JSON::ParserError
          0
        end
      end

      # Render a single bulk action button or link
      # @param action [Spree::Admin::Table::BulkAction] the bulk action
      # @param options [Hash] additional options for the link
      # @return [String] rendered HTML
      def render_bulk_action(action, **options)
        return unless action.visible?(self)

        link_options = {
          class: options[:class] || 'btn',
          data: {
            action: 'click->bulk-operation#setBulkAction click->bulk-dialog#open',
            turbo_frame: :bulk_dialog,
            url: action.action_path
          }
        }

        link_options[:data][:confirm] = action.confirm if action.confirm.present?

        content = if action.icon.present?
                    icon(action.icon) + ' ' + action.resolve_label
                  else
                    action.resolve_label
                  end

        link_to content, action.modal_path, link_options
      end

      # Render bulk actions panel for a table
      # @param table [Spree::Admin::Table] the table
      # @param options [Hash] additional options
      # @return [String] rendered HTML
      def render_bulk_actions_panel(table)
        actions = table.visible_bulk_actions(self)
        return if actions.empty?

        # Split actions into primary (first 2) and secondary (rest in dropdown)
        primary_actions = actions.first(2)
        secondary_actions = actions.drop(2)

        content_tag(:div, id: 'bulk-panel', class: 'hidden', data: { bulk_operation_target: 'panel' }) do
          content_tag(:div, class: 'bulk-panel-container') do
            parts = []
            parts << bulk_operations_counter

            primary_actions.each do |action|
              parts << render_bulk_action(action)
            end

            if secondary_actions.any?
              parts << render_bulk_actions_dropdown(secondary_actions)
            end

            parts << bulk_operations_close_button
            safe_join(parts)
          end
        end
      end

      # Render dropdown for secondary bulk actions
      # @param actions [Array<Spree::Admin::Table::BulkAction>] the actions
      # @return [String] rendered HTML
      def render_bulk_actions_dropdown(actions)
        dropdown(direction: 'top', portal: false) do
          toggle = dropdown_toggle do
            icon('dots-vertical', class: 'mr-0')
          end

          menu = dropdown_menu(class: 'mb-2') do
            items = actions.map do |action|
              render_bulk_action(action, class: 'dropdown-item')
            end
            safe_join(items)
          end

          safe_join([toggle, menu])
        end
      end

      private

      def find_sort_label(sortable, current_sort)
        return Spree.t('admin.tables.sort_by') if current_sort.blank?

        field, direction = current_sort.split(' ')
        column = sortable.find { |c| c.ransack_attribute == field }

        if column
          dir_label = direction == 'asc' ? 'ASC' : 'DESC'
          "#{column.resolve_label} (#{dir_label})"
        else
          Spree.t('admin.tables.sort_by')
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

      # Recursively count filters in a state object (including nested groups)
      # @param state [Hash] the state object
      # @return [Integer] count of filters
      def count_filters_in_state(state)
        return 0 unless state.is_a?(Hash)

        count = 0

        # Count filters at this level (only those with a field selected)
        if state['filters'].is_a?(Array)
          count += state['filters'].count { |f| f['field'].present? }
        end

        # Count filters in nested groups
        if state['groups'].is_a?(Array)
          state['groups'].each do |group|
            count += count_filters_in_state(group)
          end
        end

        count
      end
    end
  end
end
