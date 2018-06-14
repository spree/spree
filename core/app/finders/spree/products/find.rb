module Spree
  module Products
    class Find
      def initialize(scope, params = {})
        @scope = scope
      end

      def call

      end

      private

      attr_reader :scope
    end
  end
end
