# Main module for authentication.  
# Include this in ApplicationController to activate RoleRequirement
#
# See RoleSecurityClassMethods for some methods it provides.
module RoleRequirementSystem
  def self.included(klass)
    klass.send :class_inheritable_array, :role_requirements
    klass.send :include, RoleSecurityInstanceMethods
    klass.send :extend, RoleSecurityClassMethods
    klass.send :helper_method, :url_options_authenticate? 
    
    klass.send :role_requirements=, []
    
  end
  
  module RoleSecurityClassMethods
    
    def reset_role_requirements!
      self.role_requirements.clear
    end
    
    # Add this to the top of your controller to require a role in order to access it.
    # Example Usage:
    # 
    #    require_role "contractor"
    #    require_role "admin", :only => :destroy # don't allow contractors to destroy
    #    require_role "admin", :only => :update, :unless => "current_user.authorized_for_listing?(params[:id]) "
    #
    # Valid options
    #
    #  * :only - Only require the role for the given actions
    #  * :except - Require the role for everything but 
    #  * :if - a Proc or a string to evaluate.  If it evaluates to true, the role is required.
    #  * :unless - The inverse of :if
    #    
    def require_role(roles, options = {})
      options.assert_valid_keys(:if, :unless,
        :for, :only, 
        :for_all_except, :except
      )
      
      # only declare that before filter once
      unless (@before_filter_declared||=false)
        @before_filter_declared=true
        before_filter :check_roles
      end
      
      # convert to an array if it isn't already
      roles = [roles] unless Array===roles
      
      options[:only] ||= options[:for] if options[:for]
      options[:except] ||= options[:for_all_except] if options[:for_all_except]      
            
      # convert any actions into symbols
      for key in [:only, :except]
        if options.has_key?(key)          
          options[key] = [options[key]] unless Array === options[key]
          options[key] = options[key].compact.collect{|v| v.to_sym}
        end 
      end
      
      self.role_requirements||=[]
      self.role_requirements << {:roles => roles, :options => options }      
    end
    
    # This is the core of RoleRequirement.  Here is where it discerns if a user can access a controller or not./
    def user_authorized_for?(user, params = {}, binding = self.binding)
      return true unless Array===self.role_requirements
      self.role_requirements.each{| role_requirement|
        
        roles = role_requirement[:roles]
        options = role_requirement[:options]
        # do the options match the params?
        
        # check the action
        if options.has_key?(:only)
          next unless options[:only].include?( (params[:action]||"index").to_sym )
        end
                
        if options.has_key?(:except)
          next if options[:except].include?( (params[:action]||"index").to_sym)
        end
        
        if options.has_key?(:if)
          # execute the proc.  if the procedure returns false, we don't need to authenticate these roles
          next unless ( String===options[:if] ? eval(options[:if], binding) : options[:if].call(params) )
        end
        
        if options.has_key?(:unless)
          # execute the proc.  if the procedure returns true, we don't need to authenticate these roles
          next if ( String===options[:unless] ? eval(options[:unless], binding) : options[:unless].call(params) )
        end
        
        # check to see if they have one of the required roles
        passed = false
        roles.each { |role|          
          passed = true if user.has_role?(role)
        } unless (user.nil? || user==false)
        
        return false unless passed
      }
      
      return true
    end
  end
  
  module RoleSecurityInstanceMethods
    def self.included(klass)
      #raise "Because role_requirement extends acts_as_authenticated, You must include AuthenticatedSystem first before including RoleRequirementSystem!" unless klass.included_modules.include?(AuthenticatedSystem)
    end
    
    # We want to render something when access is denied, how does this make sense?
    #
    # def access_denied
    #   if logged_in?
    #     render :nothing => true, :status => 401
    #     return false
    #   else
    #     super
    #   end
    # end
    
    def check_roles       
      return access_denied unless self.class.user_authorized_for?(current_user, params, binding)
      
      true
    end
    
  protected
    # receives a :controller, :action, and :params.  Finds the given controller and runs user_authorized_for? on it.
    # This can be called in your views, and is for advanced users only.  If you are using :if / :unless eval expressions, 
    #   then this may or may not work (eval strings use the current binding to execute, not the binding of the target 
    #   controller)
    def url_options_authenticate?(params = {})
      params = params.symbolize_keys
      if params[:controller]
        # find the controller class
        klass = eval("#{params[:controller]}_controller".classify)
      else
        klass = self.class
      end
      klass.user_authorized_for?(current_user, params, binding)
    end
  end
end