class Photo < ActiveRecord::Base
  has_many :comments, :attributes => true
end
