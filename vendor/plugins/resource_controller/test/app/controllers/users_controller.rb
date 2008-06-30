class UsersController < ResourceController::Base
  object_name :dude
  route_name :dude
  private    
    def route_name
      'dude'
    end
    
    def model_name
      'account'
    end
end
