class Admin::BaseController < Spree::BaseController
  helper :search
  helper 'admin/navigation'
  layout 'admin'

  before_filter :parse_date_params

  protected

  def ssl_required?
    ssl_supported?
  end

  def render_js_for_destroy
    render :js => "$('.flash.notice').html('#{flash[:notice]}'); $('.flash.notice').show();"
    flash[:notice] = nil
  end

  def require_object_editable_by_current_user
    return access_denied unless object.editable_by?(current_user)
    true
  end

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

