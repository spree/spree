class Admin::GeneralSettingsController < Admin::BaseController
  before_filter :load_data

  AVAILABLE_PREFERENCES = ['site_name', 'default_seo_title', 'default_meta_keywords',
                       'default_meta_description', 'site_url', 'allow_ssl_in_production',
                       'allow_ssl_in_development_and_test']

  def update
    @config = Spree::Config.instance
    @config.update_attributes(params[@config.class.name.underscore])
    Rails.cache.delete("configuration_#{@config.class.name}".to_sym)
    redirect_to admin_general_settings_path
  end

  private
  def load_data
    @preferences = AVAILABLE_PREFERENCES
  end
end
