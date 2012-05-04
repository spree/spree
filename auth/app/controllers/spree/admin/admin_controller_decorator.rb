require File.expand_path('../../base_controller_decorator', __FILE__)
Spree::Admin::BaseController.class_eval do
  before_filter :authorize_admin

  def authorize_admin
    begin
      record = model_class.new
    rescue
      record = Object.new
    end
    authorize! :admin, record
    authorize! params[:action].to_sym, record
  end

  protected
    def model_class
      "Spree::#{controller_name.classify}".constantize
    end
end
