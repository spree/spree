class PhotosController < ResourceController::Base
  actions :all, :except => :update
  
  belongs_to :user
  
  private
    def parent_model
      Account
    end
end
