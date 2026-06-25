module Spree
  module Admin
    class Table
      class Filter
        OPERATORS = {
          eq: { predicate: '_eq' },
          not_eq: { predicate: '_not_eq' },
          cont: { predicate: '_cont' },
          not_cont: { predicate: '_not_cont' },
          start: { predicate: '_start' },
          end: { predicate: '_end' },
          gt: { predicate: '_gt' },
          gteq: { predicate: '_gteq' },
          lt: { predicate: '_lt' },
          lteq: { predicate: '_lteq' },
          in: { predicate: '_in' },
          not_in: { predicate: '_not_in' },
          null: { predicate: '_null', no_value: true },
          not_null: { predicate: '_not_null', no_value: true }
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
          self.class.translate_operator(@operator)
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
            { value: key.to_s, label: translate_operator(key), no_value: config[:no_value] || false }
          end
        end

        # Translate an operator key to its human-readable label
        # @param operator [Symbol]
        # @return [String]
        def self.translate_operator(operator)
          Spree.t("admin.table.operators.#{operator}", default: operator.to_s.humanize)
        end
      end
    end
  end
end
