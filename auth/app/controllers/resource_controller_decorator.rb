# This overrides the before method provided by resource_controller so that the current_user is authorized
# for each action before proceding.
module ResourceController
  module Helpers
    module Internal
      protected
      # Calls the before block for the action, if one is present.
      def before(action)

        resource = case action
        when :index, :new, :create
          model
        else object
        end

        if resource.respond_to? :token
          authorize! action, resource, session[:access_token]
        else
          authorize! action, resource
        end
        invoke_callbacks *self.class.send(action).before
      end
    end
  end
end
