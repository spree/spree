class PhotosController < ResourceController::Base
  actions :all, :except => :update
  
  belongs_to :user
  create.flash { "#{@photo.title} was created!" }
  
  private
    def parent_model
      Account
    end
end
