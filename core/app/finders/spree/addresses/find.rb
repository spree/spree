module Spree
  module Addresses
    class Find
      def initialize(scope:, params:)
        @scope = scope
      end

      def execute
        scope
      end

      private

      attr_reader :scope
    end
  end
end
