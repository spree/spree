module Spree
  module Admin
    class GeneralSettingsController < Spree::Admin::BaseController
      include Spree::Backend::Callbacks

      before_action :set_store

      def edit
        @preferences_security = [:check_for_spree_alerts]
      end

      def update
        params.each do |name, value|
          next unless Spree::Config.has_preference? name
          Spree::Config[name] = value
        end

        current_store.update_attributes store_params

        flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:general_settings))
        redirect_to edit_admin_general_settings_path
      end

      def dismiss_alert
        if request.xhr? and params[:alert_id]
          dismissed = Spree::Config[:dismissed_spree_alerts] || ''
          Spree::Config.set dismissed_spree_alerts: dismissed.split(',').push(params[:alert_id]).join(',')
          filter_dismissed_alerts
          render nothing: true
        end
      end

      def clear_cache
        Rails.cache.clear
        invoke_callbacks(:clear_cache, :after)
        head :no_content
      end

      private
      def store_params
        params.require(:store).permit(permitted_store_attributes)
      end

      def set_store
        @store = current_store
      end
    end
  end
end
