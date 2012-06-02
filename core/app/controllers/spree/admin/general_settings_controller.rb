module Spree
  module Admin
    class GeneralSettingsController < Spree::Admin::BaseController
      def show
        @preferences = ['site_name', 'default_seo_title', 'default_meta_keywords',
                        'default_meta_description', 'site_url']
      end

      def edit
        @preferences = [:site_name, :default_seo_title, :default_meta_keywords,
                        :default_meta_description, :site_url, :allow_ssl_in_production,
                        :allow_ssl_in_staging, :allow_ssl_in_development_and_test,
                        :check_for_spree_alerts]
      end

      def update
        params.each do |name, value|
          next unless Spree::Config.has_preference? name
          Spree::Config[name] = value
        end

        redirect_to admin_general_settings_path
      end

      def dismiss_alert
        if request.xhr? and params[:alert_id]
          dismissed = Spree::Config[:dismissed_spree_alerts] || ''
          Spree::Config.set :dismissed_spree_alerts => dismissed.split(',').push(params[:alert_id]).join(',')
          filter_dismissed_alerts
          render :nothing => true
        end
      end
    end
  end
end
