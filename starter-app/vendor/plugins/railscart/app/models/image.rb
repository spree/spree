class Image < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true
  has_attachment :content_type => :image,
                 :max_size => 500.kilobyte,
                 :resize_to => [360,360],
                 :thumbnails => {:product => [240,240], :small => [100,100], :mini => [48,48]},
                 :path_prefix => 'public/images/products',
                 :storage => :file_system,
                 :processor => :MiniMagick
                 
  validates_as_attachment
end