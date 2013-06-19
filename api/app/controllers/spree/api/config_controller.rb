module Spree
  module Api
    class ConfigController < Spree::Api::BaseController
      def show
        render_if_not_stale
      end

      def money
        render_if_not_stale
      end

      private

      def render_if_not_stale
        last_preference = Spree::Preference.order("updated_at DESC").last
        if stale?(:etag => last_preference, :last_modified => last_preference.updated_at)
          render
        end
      end
    end
  end
end