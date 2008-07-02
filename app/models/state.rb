class State < ActiveRecord::Base
  belongs_to :country
  named_scope :order_by_name, :order => :name
end