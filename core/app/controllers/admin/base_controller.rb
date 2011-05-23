class Admin::BaseController < Spree::BaseController
  ssl_required

  helper :search
  helper 'admin/navigation'
  layout 'admin'

  protected
  def render_js_for_destroy
    render :partial => "/admin/shared/destroy"
  end
  
  # Index request for JSON needs to pass a CSRF token in order to prevent JSON Hijacking
  def check_json_authenticity
    return unless request.format.js? or request.format.json?
    auth_token = params[request_forgery_protection_token]
    unless (auth_token and form_authenticity_token == auth_token.gsub(' ', '+'))
      raise(ActionController::InvalidAuthenticityToken)
    end
  end

  # def require_object_editable_by_current_user
  #   return access_denied unless object.editable_by?(current_user)
  #   true
  # end
end
