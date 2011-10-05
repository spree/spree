class Api::SettingsController < Api::BaseController
  before_filter :check_admin
  private
  def check_admin
    unless User.current.has_role?("admin")
      render :text => "Access Denied\n", :status => 401
    end
  end
end

