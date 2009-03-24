# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :instantiate_controller_and_action_names

  # Pick a unique cookie name to distinguish our session data from others'
  session_options['session_key'] = '_spree_session_id'

  protect_from_forgery # See ActionController::RequestForgeryProtection for details

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
end
