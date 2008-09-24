class Image < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true
  acts_as_list :scope => :parent 
  has_attachment :content_type => :image,
                 :max_size => 500.kilobyte,
                 :thumbnails => { :mini => '48x48>', :small => '100x100>', :product => '240x240>' },
                 :path_prefix => 'public/images/products',
                 :storage => :file_system,
                 :processor => :MiniMagick
                 
  validates_as_attachment
end