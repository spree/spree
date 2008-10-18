class Image < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true
  acts_as_list :scope => :parent 
  has_attached_file :photo, :styles => { :mini => '48x48>', :small => '100x100>', :product => '240x240>' }, :default_style => :product
end