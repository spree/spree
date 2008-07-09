class Admin::MailSettingsController < Admin::BaseController

  before_filter :load_configuration
  
  def show; end
  def edit; end
  
  def update
    params[:mail_preferences].each do |key, value|
      @configuration.set_preference(key, value)
    end
    @configuration.save
    
    respond_to do |format|
      format.html {
        redirect_to admin_configuration_mail_settings_path(@configuration)
      }
    end
  end

  private

  def load_configuration
    begin
      @configuration = AppConfiguration.find(params[:configuration_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_configurations_path
    end
  end

end
