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
      # @return [Array<String>, nil]
      def session_selected_columns(table_key)
        keys = session["table_columns_#{table_key}"]
        return nil if keys.blank?

        keys.split(',')
      end

      # Render a single column value based on its type
      # @param record [Object] the record
      # @param column [Spree::Admin::Table::Column] the column definition
      # @param table [Spree::Admin::Table] the table
      # @return [String] rendered HTML
      def render_column_value(record, column, table)
        value = column.resolve_value(record, self)

        case column.type.to_s
        when 'money'
          render_money_column(value, column)
        when 'date'
          render_date_column(value, column)
        when 'datetime'
          render_datetime_column(value, column)
        when 'status'
          render_status_column(value, column)
        when 'boolean'
          render_boolean_column(value, column)
        when 'link'
          render_link_column(record, value, column, table)
        when 'image'
          render_image_column(record, value, column)
        when 'custom'
          extra_locals = column.partial_locals.is_a?(Proc) ? column.partial_locals.call(record) : column.partial_locals
          locals = { record: record, column: column, value: value }.merge(extra_locals)
          render partial: column.partial, locals: locals
        when 'association'
          render_association_column(value, column)
        else
          render_string_column(value, column)
        end
      end

      # Render placeholder for empty column values
      # @return [String]
      def empty_column_placeholder
        content_tag(:span, '-', class: 'text-gray-400')
      end

      # Render money column
      # @param value [Object] the value (Spree::Money or numeric)
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_money_column(value, column)
        return empty_column_placeholder if value.blank?

        value.respond_to?(:display_amount) ? value.display_amount : Spree::Money.new(value, currency: current_currency).to_html
      end

      # Render date column
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_date_column(value, column)
        render_temporal_column(value, column, :spree_date)
      end

      # Render datetime column
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_datetime_column(value, column)
        render_temporal_column(value, column, :spree_time_ago)
      end

      # Render temporal (date/datetime) column with optional format
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
      # @param default_formatter [Symbol] default formatter method
      # @return [String]
      def render_temporal_column(value, column, default_formatter)
        return empty_column_placeholder if value.blank?

        formatter = column.format.present? && respond_to?(column.format) ? column.format : default_formatter
        send(formatter, value)
      end

      STATUS_BADGE_CLASSES = {
        'active' => 'badge-active', 'complete' => 'badge-active', 'completed' => 'badge-active',
        'paid' => 'badge-active', 'shipped' => 'badge-active', 'available' => 'badge-active',
        'draft' => 'badge-warning', 'pending' => 'badge-warning', 'processing' => 'badge-warning', 'ready' => 'badge-warning',
        'archived' => 'badge-inactive', 'canceled' => 'badge-inactive', 'cancelled' => 'badge-inactive',
        'failed' => 'badge-inactive', 'void' => 'badge-inactive', 'inactive' => 'badge-inactive'
      }.freeze

      # Render status column as badge
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_status_column(value, column)
        return empty_column_placeholder if value.blank?

        css_class = STATUS_BADGE_CLASSES[value.to_s] || 'badge-secondary'
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
      # @param table [Spree::Admin::Table] the table
      # @return [String]
      def render_link_column(record, value, column, table = nil)
        return empty_column_placeholder if value.blank?

        truncated_value = h(value.to_s.truncate(100))
        url = resolve_link_url(record, table)
        url ? link_to(truncated_value, url, data: { turbo_frame: '_top' }) : truncated_value
      end

      # Render image column
      # @param record [Object] the record
      # @param value [Object] the value (ActiveStorage attachment or URL string)
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_image_column(record, value, column)
        return empty_column_placeholder if value.blank?

        if value.respond_to?(:attached?) && value.attached?
          spree_image_tag(value, width: 50, height: 50, class: 'rounded', loading: 'lazy')
        elsif value.is_a?(String)
          image_tag value, class: 'rounded', style: 'max-width: 50px; max-height: 50px;', loading: 'lazy'
        else
          empty_column_placeholder
        end
      end

      # Render string column
      # @param value [Object] the value
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_string_column(value, column)
        return empty_column_placeholder if value.blank?

        column.format.present? && respond_to?(column.format) ? send(column.format, value) : h(value.to_s.truncate(100))
      end

      # Render association column (e.g., taxons, tags)
      # @param value [Object] the value (expected to be a string from method lambda)
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def render_association_column(value, column)
        return empty_column_placeholder if value.blank?

        h(value.to_s.truncate(100))
      end

      # Render sort dropdown for sortable columns
      # @param table [Spree::Admin::Table] the table
      # @param current_sort [String, nil] current sort value (e.g., "name asc")
      # @return [String]
      def table_sort_dropdown(table, current_sort)
        sortable = table.sortable_columns
        return '' if sortable.empty?

        current_field, current_direction = parse_current_sort(current_sort)
        current_label = find_sort_label(sortable, current_sort)
        current_q = params[:q].respond_to?(:to_unsafe_h) ? params[:q].to_unsafe_h : (params[:q] || {})
        default_field = sortable.first.ransack_attribute

        dropdown(portal: false) do
          toggle = sort_dropdown_toggle(current_direction, current_label)
          menu = sort_dropdown_menu(sortable, current_field, current_direction, current_q, default_field)
          safe_join([toggle, menu])
        end
      end

      # Get column header CSS class
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def column_header_class(column)
        [].tap do |classes|
          classes << "text-#{column.align}" unless column.align.to_s == 'left'
          classes << "w-#{column.width}" if column.width.present?
        end.join(' ')
      end

      # Get column cell CSS class
      # @param column [Spree::Admin::Table::Column] column definition
      # @return [String]
      def column_cell_class(column)
        column.align.to_s == 'left' ? '' : "text-#{column.align}"
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
      # @param table [Spree::Admin::Table] the table (required for generating modal path)
      # @param options [Hash] additional options for the link
      # @return [String] rendered HTML
      def render_bulk_action(action, table:, **options)
        return unless action.visible?(self)

        action_path = action.action_path.is_a?(Proc) ? action.action_path.call(self) : action.action_path
        modal_path = spree.new_admin_bulk_operation_path(kind: action.key, table_key: table.key)
        confirm_message = resolve_bulk_action_confirm(action.confirm)

        link_options = {
          class: options[:class] || 'btn',
          data: {
            action: 'click->bulk-operation#setBulkAction click->bulk-dialog#open',
            turbo_frame: :bulk_dialog,
            url: action_path,
            method: action.method
          }
        }

        link_options[:data][:confirm] = confirm_message if confirm_message.present?

        content = if action.icon.present?
                    icon(action.icon) + ' ' + action.resolve_label
                  else
                    action.resolve_label
                  end

        link_to content, modal_path, link_options
      end

      # Resolve confirm message for bulk action
      # @param confirm [String, Symbol, nil] the confirm value (can be i18n key or plain string)
      # @return [String, nil]
      def resolve_bulk_action_confirm(confirm)
        return nil if confirm.blank?

        if confirm.is_a?(Symbol)
          Spree.t(confirm)
        elsif confirm.is_a?(String) && confirm.start_with?('admin.')
          Spree.t(confirm, default: confirm)
        else
          confirm
        end
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
              parts << render_bulk_action(action, table: table)
            end

            if secondary_actions.any?
              parts << render_bulk_actions_dropdown(secondary_actions, table: table)
            end

            parts << bulk_operations_close_button
            safe_join(parts)
          end
        end
      end

      # Render dropdown for secondary bulk actions
      # @param actions [Array<Spree::Admin::Table::BulkAction>] the actions
      # @param table [Spree::Admin::Table] the table (used for auto-generating modal_path)
      # @return [String] rendered HTML
      def render_bulk_actions_dropdown(actions, table: nil)
        dropdown(direction: 'top', portal: false) do
          toggle = dropdown_toggle do
            icon('dots-vertical', class: 'mr-0')
          end

          menu = dropdown_menu(class: 'mb-2') do
            items = actions.map do |action|
              render_bulk_action(action, table: table, class: 'dropdown-item')
            end
            safe_join(items)
          end

          safe_join([toggle, menu])
        end
      end

      private

      def sort_dropdown_toggle(current_direction, current_label)
        dropdown_toggle(class: 'btn-light btn-sm h-[2.125rem]') do
          safe_join([
            icon(current_direction == 'asc' ? 'sort-ascending' : 'sort-descending'),
            content_tag(:span, current_label),
            icon('chevron-down')
          ])
        end
      end

      def sort_dropdown_menu(sortable, current_field, current_direction, current_q, default_field)
        dropdown_menu(class: 'min-w-[200px]') do
          sections = [sort_dropdown_header('admin.tables.sort_by')]

          sortable.each do |column|
            is_active = current_field == column.ransack_attribute
            sort_value = "#{column.ransack_attribute} #{current_direction || 'desc'}"
            sections << sort_dropdown_item(column.resolve_label, sort_value, is_active, current_q)
          end

          sections << content_tag(:hr, '', class: 'dropdown-divider')
          sections << sort_dropdown_header('admin.tables.order')

          field = current_field.presence || default_field
          sections << sort_dropdown_item(Spree.t('admin.tables.ascending'), "#{field} asc", current_direction == 'asc', current_q)
          sections << sort_dropdown_item(Spree.t('admin.tables.descending'), "#{field} desc", current_direction != 'asc', current_q)

          safe_join(sections)
        end
      end

      def sort_dropdown_header(i18n_key)
        content_tag(:div, Spree.t(i18n_key), class: 'dropdown-header')
      end

      def sort_dropdown_item(label, sort_value, is_active, current_q)
        link_to(
          url_for(q: current_q.merge(s: sort_value)),
          class: "dropdown-item flex items-center justify-between #{'active' if is_active}",
          data: { turbo_action: 'advance' }
        ) do
          safe_join([content_tag(:span, label), is_active ? icon('check') : ''])
        end
      end

      def resolve_link_url(record, table)
        if table&.link_to_action == :show && respond_to?(:object_url)
          object_url(record) rescue nil
        elsif respond_to?(:edit_object_url)
          edit_object_url(record) rescue nil
        end
      end

      def parse_current_sort(current_sort)
        return [nil, nil] if current_sort.blank?

        current_sort.split(' ', 2)
      end

      def find_sort_label(sortable, current_sort)
        return Spree.t('admin.tables.sort_by') if current_sort.blank?

        field, = parse_current_sort(current_sort)
        column = sortable.find { |c| c.ransack_attribute == field }
        column&.resolve_label || Spree.t('admin.tables.sort_by')
      end

      # Recursively count filters in a state object (including nested groups)
      # @param state [Hash] the state object
      # @return [Integer] count of filters
      def count_filters_in_state(state)
        return 0 unless state.is_a?(Hash)

        filters_count = Array(state['filters']).count { |f| f['field'].present? }
        groups_count = Array(state['groups']).sum { |group| count_filters_in_state(group) }
        filters_count + groups_count
      end
    end
  end
end
