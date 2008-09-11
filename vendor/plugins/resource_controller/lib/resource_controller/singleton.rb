module ResourceController
  
  # == ResourceController::Singleton
  # 
  # Inherit from this class to create your RESTful singleton controller.  See the README for usage.
  # 
  class Singleton < ApplicationController
    unloadable
    
    def self.inherited(subclass)
      super
      subclass.class_eval { resource_controller :singleton }
    end
  end
end