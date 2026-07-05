module Spree
  module Admin
    module TableConcern
      extend ActiveSupport::Concern

      included do
        class_attribute :_table_key, instance_writer: false
      end

      class_methods do
        # Override the table key for this controller
        # By default, the key is derived from controller_name (e.g., ProductsController -> :products)
        # @param key [Symbol] the table key (e.g., :products)
        def use_table(key)
          self._table_key = key
        end
      end

      # Get the table key for this controller
      # Uses explicitly set key or derives from controller_name
      # @return [Symbol]
      def table_key
        _table_key || controller_name.to_sym
      end

      # Get the table for this controller
      # @return [Spree::Admin::Table, nil]
      def table
        @table ||= Spree.admin.tables.get(table_key)
      end

      # Check if a table is registered for this controller
      # @return [Boolean]
      def table_registered?
        Spree.admin.tables.registered?(table_key)
      end

      # Apply custom sort scopes if the table has them configured
      # Should be called after ransack result is obtained
      # @param collection [ActiveRecord::Relation] the collection to sort
      # @return [ActiveRecord::Relation] sorted collection
      def apply_table_sort(collection)
        return collection unless table
        return collection unless params[:q].respond_to?(:dig)

        sort_param = params.dig(:q, :s)
        column = table.find_custom_sort_column(sort_param)

        return collection unless column

        # Remove sort from ransack params since we'll apply it manually
        table.apply_custom_sort(collection.reorder(nil), sort_param)
      end

      # Check if current sort uses a custom scope
      # @return [Boolean]
      def custom_sort_active?
        return false unless table
        return false unless params[:q].respond_to?(:dig)

        sort_param = params.dig(:q, :s)
        table.find_custom_sort_column(sort_param).present?
      end

      # Process query_state parameter from table query builder
      # and merge it into params[:q] for ransack
      # @return [void]
      def process_table_query_state
        return unless params[:query_state].present?

        query_builder = Spree::Admin::Table::QueryBuilder.new(table)
        query_builder.load_from_json(params[:query_state])

        ransack_params = query_builder.to_ransack_params
        return if ransack_params.blank?

        params[:q] ||= {}
        params[:q].merge!(ransack_params)
      end
    end
  end
end
