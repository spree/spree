module Spree
  module Products
    class OptionTypeFiltersPresenter
      def initialize(option_values)
        @option_values = option_values
      end

      def to_a
        grouped_options.map { |option_type, option_values| option_type_hash(option_type, option_values) }
      end

      private

      attr_reader :option_values

      def grouped_options
        option_values.group_by(&:option_type)
      end

      def option_type_hash(option_type, option_values)
        {
          id: option_type.id,
          name: option_type.name,
          presentation: option_type.presentation,
          option_values: option_values.map { |e| option_value_hash(e) }
        }
      end

      def option_value_hash(option_value)
        {
          id: option_value.id,
          name: option_value.name,
          presentation: option_value.presentation,
          position: option_value.position
        }
      end
    end
  end
end
