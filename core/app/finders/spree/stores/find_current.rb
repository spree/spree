module Spree
  module Stores
    class FindCurrent
      def initialize(scope: nil, url: nil)
        @scope = scope || Spree::Store
        @url = url
      end

      def execute
        by_url(scope) || scope.default
      end

      protected

      attr_reader :scope, :url

      def by_url(scope)
        return if url.blank?

        scope.by_url(url).first
      end
    end
  end
end
