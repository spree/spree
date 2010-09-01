Admin::BaseController.class_eval do
  before_filter :authorize_admin

  def authorize_admin
    authorize! :admin, Object
  end
end