module Spree
  module Menus
    class Find < ::Spree::BaseFinder
      def execute
        return scope.where(unique_code: params[:filter]['unique_code']) if params[:filter].present?

        scope
      end
    end
  end
end
