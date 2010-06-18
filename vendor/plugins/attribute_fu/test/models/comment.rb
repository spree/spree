class Comment < ActiveRecord::Base
  belongs_to :photo
  validates :author, :body, :presence => true
  
  def blank?
    author.blank? && body.blank?
  end
end
