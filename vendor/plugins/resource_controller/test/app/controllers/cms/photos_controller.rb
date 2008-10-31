class Cms::PhotosController < ResourceController::Base
  actions :all, :except => :update
  
  belongs_to :personnel
  create.flash { "#{@photo.title} was created!" }  
end
