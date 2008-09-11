class ImagesController < ResourceController::Singleton
  belongs_to :user
  actions :create
end