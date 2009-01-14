# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :instantiate_controller_and_action_names
  before_filter :set_user_language

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_spree_session_id'

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store 
  # (SECURITY WARNING: Choose you own secret key, do not use the one below without changing it!)
  protect_from_forgery #:secret => '55a66755bef2c41d411bd5486c001b16'

  include AuthenticatedSystem
  include RoleRequirementSystem
  include EasyRoleRequirementSystem
  include SslRequirement
  
  private 
  
  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
    
    @taxonomies = Taxonomy.find(:all, :include => {:root => :children})
  end
  
  def set_user_language
    locale = session[:locale] || Spree::Config[:default_locale] || I18n.default_locale
    locale = AVAILABLE_LOCALES.keys.include?(locale) ? locale : I18n.default_locale
    I18n.locale = locale
  end
end
