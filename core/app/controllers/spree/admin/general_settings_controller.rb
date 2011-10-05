module Spree
  module Admin
    class GeneralSettingsController < BaseController

      def show
        @preferences = ['site_name', 'default_seo_title', 'default_meta_keywords',
                        'default_meta_description', 'site_url']
      end
  
      def edit
        @preferences = ['site_name', 'default_seo_title', 'default_meta_keywords',
                        'default_meta_description', 'site_url', 'allow_ssl_in_production',
                        'allow_ssl_in_development_and_test']
      end

      def update
        @config = Spree::Config.instance
        @config.update_attributes(params[@config.class.name.underscore])
        Rails.cache.delete("configuration_#{@config.class.name}".to_sym)
        redirect_to admin_general_settings_path
      end

    end
  end
end
