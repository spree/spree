module Spree
  module Admin
    module RecordListConcern
      extend ActiveSupport::Concern

      included do
        class_attribute :_record_list_key, instance_writer: false
      end

      class_methods do
        # Override the record list key for this controller
        # By default, the key is derived from controller_name (e.g., ProductsController -> :products)
        # @param key [Symbol] the record list key (e.g., :products)
        def use_record_list(key)
          self._record_list_key = key
        end
      end

      # Get the record list key for this controller
      # Uses explicitly set key or derives from controller_name
      # @return [Symbol]
      def record_list_key
        _record_list_key || controller_name.to_sym
      end

      # Get the record list for this controller
      # @return [Spree::Admin::RecordList, nil]
      def record_list
        @record_list ||= Spree.admin.record_lists.get(record_list_key)
      end

      # Apply custom sort scopes if the record list has them configured
      # Should be called after ransack result is obtained
      # @param collection [ActiveRecord::Relation] the collection to sort
      # @return [ActiveRecord::Relation] sorted collection
      def apply_record_list_sort(collection)
        return collection unless record_list

        sort_param = params.dig(:q, :s)
        column = record_list.find_custom_sort_column(sort_param)

        return collection unless column

        # Remove sort from ransack params since we'll apply it manually
        record_list.apply_custom_sort(collection.reorder(nil), sort_param)
      end

      # Check if current sort uses a custom scope
      # @return [Boolean]
      def custom_sort_active?
        return false unless record_list

        sort_param = params.dig(:q, :s)
        record_list.find_custom_sort_column(sort_param).present?
      end
    end
  end
end
