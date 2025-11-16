module Spree
  module Admin
    class OauthApplicationsController < ResourceController
      include Spree::Admin::SettingsConcern

      before_action :set_default_scopes, only: [:new, :edit]

      private

      def collection
        return @collection if @collection.present?

        base_collection = super

        params[:q] ||= {}
        @search = base_collection.ransack(params[:q])
        @pagy, @collection = pagy(@search.result, items: 500)

        @collection
      end

      def create_turbo_stream_enabled?
        true
      end

      def set_default_scopes
        @object.scopes = 'admin' if @object.scopes.blank?
      end

      def permitted_resource_params
        params.require(:oauth_application).permit(:name, :scopes)
      end
    end
  end
end
