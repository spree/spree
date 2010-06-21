class Admin::TrackersController < Admin::BaseController
  resource_controller

  update.wants.html { redirect_to collection_url }
  create.wants.html { redirect_to collection_url }
    
end
