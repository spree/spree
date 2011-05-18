class Admin::GeneralSettingsController < Admin::BaseController

  def update
    @config = Spree::Config.instance
    @config.update_attributes(params[@config.class.name.underscore])
    Rails.cache.delete("configuration_#{@config.class.name}".to_sym)
    redirect_to admin_general_settings_path
  end

end
