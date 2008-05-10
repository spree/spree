class TagsController < ResourceController::Base
  belongs_to :photo
  
  index.wants.js
  
  index do
    before { @products = Product.find :all }
  end
  
  create.after do
    @photo.tags << @tag if parent_type == :photo
  end
end
