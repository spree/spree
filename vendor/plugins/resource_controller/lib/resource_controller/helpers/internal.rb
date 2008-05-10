# Internal action lifecycle management.
# 
# All of these methods are used internally to execute the options, set by the user in ActionOptions and FailableActionOptions
#
module ResourceController::Helpers::Internal
  protected
    # Used to actually pass the responses along to the controller's respond_to method.
    #
    def response_for(action)
      respond_to do |wants|
        options_for(action).response.each do |method, block|
          if block.nil?
            wants.send(method)
          else
            wants.send(method) { instance_eval(&block) }
          end
        end
      end
    end
  
    # Calls the after callbacks for the action, if one is present.
    #
    def after(action)
      invoke_callbacks *options_for(action).after
    end
  
    # Calls the before block for the action, if one is present.
    #
    def before(action)
      invoke_callbacks *self.class.send(action).before
    end
    
    # Sets the flash for the action, if it is present.
    #
    def set_flash(action)
      flash[:notice] = options_for(action).flash if options_for(action).flash
    end
    
    # Returns the options for an action, which is a symbol.
    #
    # Manages splitting things like :create_fails.
    #
    def options_for(action)
      action = action == :new_action ? [action] : "#{action}".split('_').map(&:to_sym)
      options = self.class.send(action.first)
      options = options.send(action.last == :fails ? :fails : :success) if ResourceController::FAILABLE_ACTIONS.include? action.first
    
      options
    end
    
    def invoke_callbacks(*callbacks)
      unless callbacks.empty?
        callbacks.select { |callback| callback.is_a? Symbol }.each { |symbol| send(symbol) }
      
        block = callbacks.detect { |callback| callback.is_a? Proc }
        instance_eval &block unless block.nil?
      end
    end 
end
