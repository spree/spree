module Spree
  module Admin
    class GeneralSettingsController < Spree::Admin::BaseController

      def edit
        @preferences_general = [:site_name, :default_seo_title, :default_meta_keywords,
                        :default_meta_description, :site_url]
        @preferences_security = [:allow_ssl_in_production, :allow_ssl_in_staging, :allow_ssl_in_development_and_test]
        @preferences_currency = [:display_currency, :hide_cents]
      end

      def update
        params.each do |name, value|
          next unless Spree::Config.has_preference? name
          Spree::Config[name] = value
        end
        flash[:success] = Spree.t(:successfully_updated, :resource => Spree.t(:general_settings))

        redirect_to edit_admin_general_settings_path
      end

      def clear_cache
        Rails.cache.clear
        invoke_callbacks(:clear_cache, :after)
        head :no_content
      end
    end
  end
end
