Admin::BaseController.class_eval do
  before_filter :authorize_admin

  def authorize_admin
    begin
      model = controller_name.classify.constantize
    rescue
      model = Object
    end
    authorize! :admin, model
    authorize! params[:action].to_sym, model
  end
end