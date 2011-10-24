class Admin::BaseController < Spree::BaseController
  helper :search
  helper 'admin/navigation'
  layout 'admin'

  before_filter :parse_date_params

  before_filter :check_alerts if Rails.env.production?

  protected

  def check_alerts
    return unless current_user and should_check_alerts?

    unless session.has_key? :alerts
      begin
        session[:alerts] = Spree::Alert.current(request.host)
        filter_dismissed_alerts
        Spree::Config.set :last_check_for_spree_alerts => DateTime.now.to_s
      rescue
        session[:alerts] = nil
      end
    end
  end

  def should_check_alerts?
    return false if not Spree::Config[:check_for_spree_alerts]

    last_check = Spree::Config[:last_check_for_spree_alerts]
    return true if last_check.blank?

    DateTime.parse(last_check) < 12.hours.ago
  end

  def filter_dismissed_alerts
    return unless session[:alerts]
    dismissed = (Spree::Config[:dismissed_spree_alerts] || '').split(',')
    session[:alerts].reject! { |a| dismissed.include? a.id.to_s }
  end

  def ssl_required?
    ssl_supported?
  end

  def render_js_for_destroy
    render :js => "$('.flash.notice').html('#{self.notice}'); $('.flash.notice').show();"
    self.notice = nil
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

