class Admin::GeneralSettingsController < Admin::BaseController

  def update
    Spree::Config.set(params[:preferences])
    
    respond_to do |format|
      format.html {
        redirect_to admin_general_settings_path
      }
    end
  end

end
