class Comment < ActiveRecord::Base
  belongs_to :photo
  validates_presence_of :author, :body
  
  def blank?
    author.blank? && body.blank?
  end
end
