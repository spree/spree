class Photo < ActiveRecord::Base
  has_and_belongs_to_many :tags
  belongs_to :user, :class_name => "Account", :foreign_key => "account_id"
end
