class Admin::BaseController < Spree::BaseController
  ssl_required

  helper :search
  helper 'admin/navigation'
  layout 'admin'

  before_filter :parse_date_params

  protected
  def render_js_for_destroy
    render :partial => "/admin/shared/destroy"
    flash.notice = nil
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

  private
  def parse_date_params
    params.each do |k, v|
      parse_date_params_for(v) if v.is_a?(Hash)
    end
  end

  def parse_date_params_for(hash)
    dates = []
    hash.each do |k, v|
      parse_date_params_for(v) if v.is_a?(Hash)
      if k =~ /\(\di\)$/
        param_name = k[/^\w+/]
        dates << param_name
      end
    end
    if (dates.size > 0)
      dates.uniq.each do |date|
        hash[date] = [hash.delete("#{date}(1i)"), hash.delete("#{date}(2i)"), hash.delete("#{date}(3i)")].join('-')
      end
    end
  end
end

