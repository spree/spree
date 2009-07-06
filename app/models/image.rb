class Image < Asset
  has_attached_file :attachment, 
                    :styles => { :mini => '48x48>', :small => '100x100>', :product => '240x240>', :large => '600x600>' }, 
                    :default_style => :product,
                    :url => "/assets/products/:id/:style/:basename.:extension",
                    :path => ":rails_root/public/assets/products/:id/:style/:basename.:extension"

  before_save :find_dimensions
  
  # save the w,h of the original image 
  # assumes ImageMagick toolset installed
  def find_dimensions
    original_file = File.join('.', 'public', attachment.url(:original).gsub(/\?\d+$/, ''))
    `identify #{original_file}` =~ /.*?(\d+)x(\d+).*/
    
    unless $1.blank? || $2.blank?
      self.attachment_width  = $1
      self.attachment_height = $2 
    end
  end
end
