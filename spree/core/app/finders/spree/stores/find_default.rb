module Spree
  module Stores
    class FindDefault
      def initialize(scope: nil, url: nil)
        @scope = scope || Spree::Store
      end

      def execute
        store = @scope.where(default: true).first || @scope.first
        return if store.nil?

        Spree::Current.store = store
        store
      end
    end
  end
end
