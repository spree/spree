module Spree
  module Filters
    class OptionsPresenter
      FilterableOptionType = Struct.new(:option_type, :option_values, keyword_init: true) do
        delegate_missing_to :option_type
      end

      def initialize(option_values_scope:)
        @option_values = option_values_scope.includes(:option_type)
      end

      def to_a
        grouped_options.map do |option_type, option_values|
          FilterableOptionType.new(option_type: option_type, option_values: option_values)
        end
      end

      private

      attr_reader :option_values

      def grouped_options
        option_values.group_by(&:option_type)
      end
    end
  end
end
