module ResourceController
  ACTIONS          = [:index, :show, :new_action, :create, :edit, :update, :destroy].freeze
  FAILABLE_ACTIONS = ACTIONS - [:index, :new_action, :edit].freeze
  NAME_ACCESSORS   = [:model_name, :route_name, :object_name]  
  
  module ActionControllerExtension
    unloadable
    
    def resource_controller
      include ResourceController::Controller
    end
  end
end
