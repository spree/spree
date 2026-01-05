module Spree
  module Admin
    class Table
      class Filter
        OPERATORS = {
          eq: { label: 'equals', predicate: '_eq' },
          not_eq: { label: 'does not equal', predicate: '_not_eq' },
          cont: { label: 'contains', predicate: '_cont' },
          not_cont: { label: 'does not contain', predicate: '_not_cont' },
          start: { label: 'starts with', predicate: '_start' },
          end: { label: 'ends with', predicate: '_end' },
          gt: { label: 'greater than', predicate: '_gt' },
          gteq: { label: 'greater than or equal to', predicate: '_gteq' },
          lt: { label: 'less than', predicate: '_lt' },
          lteq: { label: 'less than or equal to', predicate: '_lteq' },
          in: { label: 'is any of', predicate: '_in' },
          not_in: { label: 'is none of', predicate: '_not_in' },
          null: { label: 'is empty', predicate: '_null', no_value: true },
          not_null: { label: 'is not empty', predicate: '_not_null', no_value: true }
        }.freeze

        attr_accessor :field, :operator, :value, :id

        def initialize(field: nil, operator: :eq, value: nil, id: nil)
          @field = field
          @operator = operator.to_sym
          @value = value
          @id = id || SecureRandom.hex(8)
        end

        # Convert to ransack parameter format
        # @return [Hash]
        def to_ransack_param
          return {} if field.blank?

          operator_config = OPERATORS[@operator]
          return {} unless operator_config

          param_name = "#{field}#{operator_config[:predicate]}"

          if operator_config[:no_value]
            { param_name => true }
          else
            { param_name => extract_ransack_value }
          end
        end

        private

        # Extract the actual value for ransack from potentially complex value structures
        # Handles arrays of objects (from autocomplete) by extracting IDs
        # @return [Object]
        def extract_ransack_value
          return value unless value.is_a?(Array)

          # Extract IDs if array contains hashes with 'id' key (from autocomplete)
          extracted = if value.first.is_a?(Hash) && (value.first.key?('id') || value.first.key?(:id))
                        value.map { |item| item['id'] || item[:id] }
                      else
                        value
                      end

          # For eq/not_eq operators, use single value instead of array
          if %i[eq not_eq].include?(@operator) && extracted.is_a?(Array) && extracted.size == 1
            extracted.first
          else
            extracted
          end
        end

        public

        # Get human-readable operator label
        # @return [String]
        def operator_label
          OPERATORS.dig(@operator, :label) || @operator.to_s.humanize
        end

        # Check if this operator requires a value
        # @return [Boolean]
        def requires_value?
          !OPERATORS.dig(@operator, :no_value)
        end

        # Convert to hash
        # @return [Hash]
        def to_h
          { field: field, operator: operator, value: value, id: id }
        end

        # Create filter from params hash
        # @param params [Hash]
        # @return [Filter, nil]
        def self.from_params(params)
          return nil unless params.is_a?(Hash)

          params = params.symbolize_keys
          new(
            field: params[:field],
            operator: params[:operator] || :eq,
            value: params[:value],
            id: params[:id]
          )
        end

        # Get available operators with labels for UI
        # @return [Array<Hash>]
        def self.operators_for_select
          OPERATORS.map do |key, config|
            { value: key.to_s, label: config[:label], no_value: config[:no_value] || false }
          end
        end
      end
    end
  end
end
