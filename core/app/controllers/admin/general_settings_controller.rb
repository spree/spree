class Admin::GeneralSettingsController < Admin::BaseController

  def update
    Spree::Config.set(params[:preferences])

    respond_to do |format|
      format.html {
        redirect_to admin_general_settings_path
      }
    end
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
