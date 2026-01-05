module Spree
  module Admin
    class RecordList
      attr_reader :columns, :context, :model_class
      attr_accessor :search_param, :search_placeholder

      def initialize(context, model_class: nil, search_param: :name_cont, search_placeholder: nil)
        @context = context
        @model_class = model_class
        @columns = {}
        @search_param = search_param
        @search_placeholder = search_placeholder
      end

      # Add a column definition
      # @param key [Symbol] unique column identifier
      # @param options [Hash] column options (label, type, sortable, filterable, default, position, etc.)
      # @return [Column] the created column
      def add(key, **options, &block)
        key = key.to_sym
        column = Column.new(key, **options)
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

        options.each do |attr, value|
          column.send("#{attr}=", value) if column.respond_to?("#{attr}=")
        end

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

      # Get filterable columns (columns that can be used in query builder)
      # @return [Array<Column>]
      def filterable_columns
        @columns.values.select(&:filterable?).sort_by(&:position)
      end

      # Deep clone the registry
      # @return [RecordList]
      def deep_clone
        cloned = self.class.new(context, model_class: model_class, search_param: search_param, search_placeholder: search_placeholder)
        @columns.each do |key, column|
          cloned.columns[key] = column.deep_clone
        end
        cloned
      end

      # Clear all columns
      def clear
        @columns.clear
      end

      def inspect
        "#<Spree::Admin::RecordList context=#{context} columns=#{@columns.size}>"
      end

      private

      def sort_columns!
        @columns = @columns.sort_by { |_key, col| [col.position, col.key.to_s] }.to_h
      end
    end
  end
end
