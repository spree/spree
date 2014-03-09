module Spree
  module Admin
    class GeneralSettingsController < Spree::Admin::BaseController
      before_filter :set_store

      def edit
        @preferences_security = [:allow_ssl_in_production,
                        :allow_ssl_in_staging, :allow_ssl_in_development_and_test,
                        :check_for_spree_alerts]
        @preferences_currency = [:display_currency, :hide_cents]
      end

      def update
        params.each do |name, value|
          next unless Spree::Config.has_preference? name
          Spree::Config[name] = value
        end

        @store.update_attributes store_params

        flash[:success] = Spree.t(:successfully_updated, :resource => Spree.t(:general_settings))

        redirect_to edit_admin_general_settings_path
      end

      def dismiss_alert
        if request.xhr? and params[:alert_id]
          dismissed = Spree::Config[:dismissed_spree_alerts] || ''
          Spree::Config.set :dismissed_spree_alerts => dismissed.split(',').push(params[:alert_id]).join(',')
          filter_dismissed_alerts
          render :nothing => true
        end
      end

      private
      def store_params
        params.require(:store).permit(permitted_params)
      end

      def permitted_params
        Spree::PermittedAttributes.store_attributes
      end

      def set_store
        @store = Spree::Store.first
      end
    end
  end
end
