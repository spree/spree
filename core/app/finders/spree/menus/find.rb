module Spree
  module Menus
    class Find < ::Spree::BaseFinder
      def execute
        return scope.where(location: params[:filter]['location']) if params[:filter].present?

        scope
      end
    end
  end
end
