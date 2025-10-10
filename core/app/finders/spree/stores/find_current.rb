module Spree
  module Stores
    class FindCurrent
      def initialize(scope: nil, url: nil)
        @scope = scope || Spree::Store
        @url = url
      end

      def execute
        store = by_url(scope) || scope.default
        return if store.nil?

        Spree::Current.store = store
        store
      end

      protected

      attr_reader :scope, :url

      def by_url(scope)
        return if url.blank?

        scope.by_custom_domain(url).or(scope.by_url(url)).first
      end
    end
  end
end
