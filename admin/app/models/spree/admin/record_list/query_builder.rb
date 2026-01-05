module Spree
  module Admin
    class RecordList
      class QueryBuilder
        attr_reader :root_group, :record_list

        def initialize(record_list)
          @record_list = record_list
          @root_group = FilterGroup.new(combinator: :and)
        end

        # Add a filter to the root group
        # @param field [String] ransack attribute name
        # @param operator [Symbol] filter operator
        # @param value [Object] filter value
        # @return [Filter]
        def add_filter(field:, operator:, value:)
          filter = Filter.new(field: field, operator: operator, value: value)
          @root_group.add_filter(filter)
          filter
        end

        # Add a nested group
        # @param combinator [Symbol] :and or :or
        # @return [FilterGroup]
        def add_group(combinator: :and)
          group = FilterGroup.new(combinator: combinator)
          @root_group.add_group(group)
          group
        end

        # Clear all filters
        def clear
          @root_group = FilterGroup.new(combinator: :and)
        end

        # Check if there are any filters
        # @return [Boolean]
        def empty?
          @root_group.empty?
        end

        # Convert to ransack params format
        # @return [Hash]
        def to_ransack_params
          @root_group.to_ransack_params
        end

        # Convert to JSON string for storing in hidden field
        # @return [String]
        def to_json_state
          @root_group.to_h.to_json
        end

        # Load state from params hash
        # @param params [Hash]
        def load_from_params(params)
          @root_group = FilterGroup.from_params(params)
        end

        # Load state from JSON string
        # @param json_string [String]
        def load_from_json(json_string)
          return if json_string.blank?

          params = JSON.parse(json_string, symbolize_names: true)
          @root_group = FilterGroup.from_params(params)
        rescue JSON::ParserError
          @root_group = FilterGroup.new(combinator: :and)
        end

        # Get available fields for filtering based on record_list configuration
        # @return [Array<Hash>]
        def available_fields
          @record_list.filterable_columns.map do |column|
            {
              key: column.ransack_attribute,
              label: column.resolve_label,
              type: column.filter_type.to_s,
              operators: column.operators.map(&:to_s),
              value_options: format_value_options(column.value_options),
              search_url: column.search_url
            }
          end
        end

        # Get available operators for UI
        # @return [Array<Hash>]
        def available_operators
          Filter.operators_for_select
        end

        private

        def format_value_options(options)
          return nil if options.blank?

          options.map do |opt|
            if opt.is_a?(Hash)
              { value: opt[:value] || opt['value'], label: opt[:label] || opt['label'] }
            else
              { value: opt.to_s, label: opt.to_s.humanize }
            end
          end
        end
      end
    end
  end
end
