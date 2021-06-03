module Spree
  module CmsPage
    class Find < ::Spree::BaseFinder
      def execute
        return scope.where(title: params[:filter]['title']) if params[:filter].present?

        scope
      end
    end
  end
end
