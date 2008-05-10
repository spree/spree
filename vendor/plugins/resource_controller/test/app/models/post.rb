class Post < ActiveRecord::Base
  has_many :comments
end
