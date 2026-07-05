module Spree
  module Variants
    class Find
      def initialize(scope:, params:)
        @scope = scope
        @options = params.dig(:filter, :options).try(:to_unsafe_hash)
      end

      def execute
        variants = by_options(scope)
        variants.distinct
      end

      private

      attr_reader :scope, :options

      def options?
        options.present?
      end

      def by_options(variants)
        return variants unless options?

        variants_ids = options.map { |key, value| variants.with_option_value(key, value)&.ids }.compact.uniq
        variants.where(id: variants_ids.reduce(&:intersection))
      end
    end
  end
end
