module Spree
  module Admin
    class Table
      attr_reader :columns, :bulk_actions, :context, :model_class, :key
      attr_accessor :search_param, :search_placeholder, :row_actions, :row_actions_edit, :row_actions_delete, :new_resource,
                    :date_range_param, :date_range_label, :link_to_action

      def initialize(context, key: nil, model_class: nil, search_param: :name_cont, search_placeholder: nil, row_actions: false, row_actions_edit: true, row_actions_delete: false, new_resource: true, date_range_param: nil, date_range_label: nil, link_to_action: :edit)
        @context = context
        @key = key
        @model_class = model_class
        @columns = {}
        @bulk_actions = {}
        @search_param = search_param
        @search_placeholder = search_placeholder
        @row_actions = row_actions
        @row_actions_edit = row_actions_edit
        @row_actions_delete = row_actions_delete
        @new_resource = new_resource
        @date_range_param = date_range_param
        @date_range_label = date_range_label
        @link_to_action = link_to_action
      end

      # Check if date range filter is enabled
      # @return [Boolean]
      def date_range?
        @date_range_param.present?
      end

      # Check if row actions are enabled
      # @return [Boolean]
      def row_actions?
        @row_actions
      end

      # Check if edit row action is enabled
      # @return [Boolean]
      def row_actions_edit?
        @row_actions_edit
      end

      # Check if delete row action is enabled
      # @return [Boolean]
      def row_actions_delete?
        @row_actions_delete
      end

      # Add a column definition
      # @param key [Symbol] unique column identifier
      # @param options [Hash] column options (label, type, sortable, filterable, default, position, etc.)
      # @return [Column] the created column
      # @raise [ArgumentError] if column configuration is invalid
      def add(key, **options, &block)
        key = key.to_sym
        # Handle :if as alias for :condition
        options[:condition] = options.delete(:if) if options.key?(:if)
        column = Column.new(**options.merge(key: key.to_s))

        unless column.valid?
          errors = column.errors.full_messages.join(', ')
          raise ArgumentError, "Invalid column '#{key}' in table '#{@context}': #{errors}"
        end

        @columns[key] = column

        if block_given?
          builder = Builder.new(self, column)
          builder.instance_eval(&block)
        end

        sort_columns!
        column
      end

      # Remove a column
      # @param key [Symbol] column key to remove
      # @return [Column, nil] the removed column or nil
      def remove(key)
        @columns.delete(key.to_sym)
      end

      # Update an existing column
      # @param key [Symbol] column key to update
      # @param options [Hash] attributes to update
      # @return [Column, nil] the updated column or nil
      def update(key, **options)
        column = @columns[key.to_sym]
        return nil unless column

        apply_attributes(column, options)
        sort_columns!
        column
      end

      # Find a column by key
      # @param key [Symbol] column key
      # @return [Column, nil]
      def find(key)
        @columns[key.to_sym]
      end

      # Check if column exists
      # @param key [Symbol] column key
      # @return [Boolean]
      def exists?(key)
        @columns.key?(key.to_sym)
      end

      # Insert column before another column
      # @param target_key [Symbol] existing column key
      # @param new_key [Symbol] new column key
      # @param options [Hash] column options
      # @return [Column, nil]
      def insert_before(target_key, new_key, **options)
        target = find(target_key)
        return nil unless target

        add(new_key, **options.merge(position: target.position - 1))
      end

      # Insert column after another column
      # @param target_key [Symbol] existing column key
      # @param new_key [Symbol] new column key
      # @param options [Hash] column options
      # @return [Column, nil]
      def insert_after(target_key, new_key, **options)
        target = find(target_key)
        return nil unless target

        add(new_key, **options.merge(position: target.position + 1))
      end

      # Get visible columns for user (respecting selection)
      # @param selected_keys [Array<Symbol>, nil] user-selected column keys
      # @param view_context [Object, nil] view context for visibility checks
      # @return [Array<Column>]
      def visible_columns(selected_keys = nil, view_context = nil)
        cols = if selected_keys.present?
                 selected_keys.map { |k| find(k) }.compact
               else
                 default_columns
               end

        cols.select { |c| c.visible?(view_context) }
      end

      # Get default columns (marked as default: true and displayable)
      # @return [Array<Column>]
      def default_columns
        @columns.values.select { |c| c.default? && c.displayable? }.sort_by(&:position)
      end

      # Get all available columns that can be displayed
      # @return [Array<Column>]
      def available_columns
        @columns.values.select(&:displayable?).sort_by(&:position)
      end

      # Get sortable columns
      # @return [Array<Column>]
      def sortable_columns
        @columns.values.select(&:sortable?).sort_by(&:position)
      end

      # Find column with custom sort scope for the given sort param
      # @param sort_param [String] the sort param (e.g., "master_price desc")
      # @return [Column, nil] column with custom sort scope or nil
      def find_custom_sort_column(sort_param)
        return nil if sort_param.blank?

        attribute = sort_param.to_s.split.first
        @columns.values.find { |c| c.ransack_attribute == attribute && c.custom_sort? }
      end

      # Apply custom sort scope to collection
      # @param collection [ActiveRecord::Relation] the collection to sort
      # @param sort_param [String] the sort param (e.g., "master_price desc")
      # @return [ActiveRecord::Relation] sorted collection
      def apply_custom_sort(collection, sort_param)
        column = find_custom_sort_column(sort_param)
        return collection unless column

        direction = sort_param.to_s.include?('desc') ? :desc : :asc
        scope_name = direction == :desc ? column.sort_scope_desc : column.sort_scope_asc

        return collection unless scope_name.present?

        collection.send(scope_name)
      end

      # Get filterable columns (columns that can be used in query builder)
      # @return [Array<Column>]
      def filterable_columns
        @columns.values.select(&:filterable?).sort_by(&:position)
      end

      # Add a bulk action definition
      # @param key [Symbol] unique action identifier
      # @param options [Hash] action options (label, icon, action_path, position, etc.)
      # @return [BulkAction] the created action
      # @raise [ArgumentError] if action configuration is invalid
      def add_bulk_action(key, **options)
        key = key.to_sym
        action = BulkAction.new(**options.merge(key: key))

        unless action.valid?
          errors = action.errors.full_messages.join(', ')
          raise ArgumentError, "Invalid bulk action '#{key}' in table '#{@context}': #{errors}"
        end

        @bulk_actions[key] = action
        sort_bulk_actions!
        action
      end

      # Remove a bulk action
      # @param key [Symbol] action key to remove
      # @return [BulkAction, nil] the removed action or nil
      def remove_bulk_action(key)
        @bulk_actions.delete(key.to_sym)
      end

      # Update an existing bulk action
      # @param key [Symbol] action key to update
      # @param options [Hash] attributes to update
      # @return [BulkAction, nil] the updated action or nil
      def update_bulk_action(key, **options)
        action = @bulk_actions[key.to_sym]
        return nil unless action

        apply_attributes(action, options)
        sort_bulk_actions!
        action
      end

      # Find a bulk action by key
      # @param key [Symbol] action key
      # @return [BulkAction, nil]
      def find_bulk_action(key)
        @bulk_actions[key.to_sym]
      end

      # Get visible bulk actions for the given context
      # @param view_context [Object, nil] view context for visibility checks
      # @return [Array<BulkAction>]
      def visible_bulk_actions(view_context = nil)
        @bulk_actions.values.select { |a| a.visible?(view_context) }.sort_by(&:position)
      end

      # Check if bulk operations are enabled (has any bulk actions)
      # @return [Boolean]
      def bulk_operations_enabled?
        @bulk_actions.any?
      end

      # Deep clone the registry
      # @return [Table]
      def deep_clone
        cloned = self.class.new(
          context,
          model_class: model_class,
          search_param: search_param,
          search_placeholder: search_placeholder,
          row_actions: row_actions,
          row_actions_edit: row_actions_edit,
          row_actions_delete: row_actions_delete,
          new_resource: new_resource,
          date_range_param: date_range_param,
          date_range_label: date_range_label,
          link_to_action: link_to_action
        )
        @columns.each do |key, column|
          cloned.columns[key] = column.deep_clone
        end
        @bulk_actions.each do |key, action|
          cloned.bulk_actions[key] = action.deep_clone
        end
        cloned
      end

      # Clear all columns
      def clear
        @columns.clear
      end

      # Clear all bulk actions
      def clear_bulk_actions
        @bulk_actions.clear
      end

      def inspect
        "#<Spree::Admin::Table context=#{context} columns=#{@columns.size} bulk_actions=#{@bulk_actions.size}>"
      end

      private

      def apply_attributes(object, options)
        options.each do |attr, value|
          object.send("#{attr}=", value) if object.respond_to?("#{attr}=")
        end
      end

      def sort_columns!
        @columns = @columns.sort_by { |_key, col| [col.position, col.key.to_s] }.to_h
      end

      def sort_bulk_actions!
        @bulk_actions = @bulk_actions.sort_by { |_key, action| [action.position, action.key.to_s] }.to_h
      end
    end
  end
end
