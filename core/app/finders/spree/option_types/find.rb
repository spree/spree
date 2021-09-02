module Spree
  module OptionTypes
    class Find < ::Spree::BaseFinder
      def execute
        return scope.filterable if params[:filter].present? && params[:filter]['filterable'].present?

        scope
      end
    end
  end
end
