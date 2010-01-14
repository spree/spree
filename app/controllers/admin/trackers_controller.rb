class Admin::TrackersController < Admin::BaseController
  resource_controller

  update.wants.html { redirect_to edit_object_url }
  create.wants.html { redirect_to edit_object_url }
    
end
