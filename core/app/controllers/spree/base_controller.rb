class Spree::BaseController < ApplicationController
  include Spree::Core::RespondWith

  layout :get_layout
  before_filter :set_user_language
  before_filter :set_current_order

  helper_method :title
  helper_method :title=
  helper_method :accurate_title
  helper_method :get_taxonomies
  helper_method :current_order

  include SslRequirement
  include Spree::Core::CurrentOrder

  rescue_from CanCan::AccessDenied do |exception|
    return unauthorized
  end

  # To be overriden by authentication providers
  def spree_current_user
    nil
  end

  def access_forbidden
    render :text => 'Access Forbidden', :layout => true, :status => 401
  end

  # can be used in views as well as controllers.
  # e.g. <% title = 'This is a custom title for this view' %>
  attr_writer :title

  def title
    title_string = @title.present? ? @title : accurate_title
    if title_string.present?
      if Spree::Config[:always_put_site_name_in_title]
        [default_title, title_string].join(' - ')
      else
        title_string
      end
    else
      default_title
    end
  end

  protected

  def set_current_order
    if spree_current_user
      last_incomplete_order = spree_current_user.last_incomplete_spree_order
      if session[:order_id].nil? && last_incomplete_order
        session[:order_id] = last_incomplete_order.id
      elsif current_order && last_incomplete_order && current_order != last_incomplete_order
        current_order.merge!(last_incomplete_order)
      end
    end
  end

  # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
  def current_ability
    @current_ability ||= Spree::Ability.new(spree_current_user)
  end

  def store_location
    # disallow return to login, logout, signup pages
    authentication_routes = [:spree_signup_path, :spree_login_path, :spree_logout_path]
    disallowed_urls = []
    authentication_routes.each do |route|
      if respond_to?(route)
        disallowed_urls << send(route)
      end
    end

    disallowed_urls.map!{ |url| url[/\/\w+$/] }
    unless disallowed_urls.include?(request.fullpath)
      session['user_return_to'] = request.fullpath.gsub('//', '/')
    end
  end

  # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
  # Override this method in your controllers if you want to have special behavior in case the user is not authorized
  # to access the requested action.  For example, a popup window might simply close itself.
  def unauthorized
    respond_to do |format|
      format.html do
        if spree_current_user
          flash.now[:error] = t(:authorization_failure)
          render 'spree/shared/unauthorized', :layout => '/spree/layouts/spree_application', :status => 401
        else
          store_location
          url = respond_to?(:spree_login_path) ? spree_login_path : root_path
          redirect_to url
        end
      end
      format.xml do
        request_http_basic_authentication 'Web Password'
      end
      format.json do
        render :text => "Not Authorized \n", :status => 401
      end
    end
  end

  def default_title
    Spree::Config[:site_name]
  end

  # this is a hook for subclasses to provide title
  def accurate_title
    Spree::Config[:default_seo_title]
  end

  def render_404(exception = nil)
    respond_to do |type|
      type.html { render :status => :not_found, :file    => "#{::Rails.root}/public/404", :formats => [:html], :layout => nil}
      type.all  { render :status => :not_found, :nothing => true }
    end
  end

  # Convenience method for firing instrumentation events with the default payload hash
  def fire_event(name, extra_payload = {})
    ActiveSupport::Notifications.instrument(name, default_notification_payload.merge(extra_payload))
  end

  # Creates the hash that is sent as the payload for all notifications. Specific notifications will
  # add additional keys as appropriate. Override this method if you need additional data when
  # responding to a notification
  def default_notification_payload
    {:user => spree_current_user, :order => current_order}
  end

  private

  def redirect_back_or_default(default)
    redirect_to(session["user_return_to"] || default)
    session["user_return_to"] = nil
  end

  def get_taxonomies
    @taxonomies ||= Spree::Taxonomy.includes(:root => :children).joins(:root)
  end

  def set_user_language
    locale = session[:locale]
    locale ||= Spree::Config[:default_locale] unless Spree::Config[:default_locale].blank?
    locale ||= Rails.application.config.i18n.default_locale
    locale ||= I18n.default_locale unless I18n.available_locales.include?(locale.to_sym)
    I18n.locale = locale.to_sym
  end

  # Returns which layout to render.
  # 
  # You can set the layout you want to render inside your Spree configuration with the +:layout+ option.
  # 
  # Default layout is: +app/views/spree/layouts/spree_application+
  # 
  def get_layout
    layout ||= Spree::Config[:layout]
  end
end
