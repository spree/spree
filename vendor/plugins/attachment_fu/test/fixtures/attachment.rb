class Attachment < ActiveRecord::Base
  @@saves = 0
  cattr_accessor :saves
  has_attachment :processor => :rmagick
  validates_as_attachment
  after_attachment_saved do |record|
    self.saves += 1
  end
end

class SmallAttachment < Attachment
  has_attachment :max_size => 1.kilobyte
end

class BigAttachment < Attachment
  has_attachment :size => 1.megabyte..2.megabytes
end

class PdfAttachment < Attachment
  has_attachment :content_type => 'pdf'
end

class DocAttachment < Attachment
  has_attachment :content_type => %w(pdf doc txt)
end

class ImageAttachment < Attachment
  has_attachment :content_type => :image, :resize_to => [50,50]
end

class ImageOrPdfAttachment < Attachment
  has_attachment :content_type => ['pdf', :image], :resize_to => 'x50'
end

class ImageWithThumbsAttachment < Attachment
  has_attachment :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
  after_resize do |record, img|
    record.aspect_ratio = img.columns.to_f / img.rows.to_f
  end
end

class FileAttachment < ActiveRecord::Base
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment
end

class ImageFileAttachment < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :content_type => :image, :resize_to => [50,50]
end

class ImageWithThumbsFileAttachment < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
  after_resize do |record, img|
    record.aspect_ratio = img.columns.to_f / img.rows.to_f
  end
end

class ImageWithThumbsClassFileAttachment < FileAttachment
  # use file_system_path to test backwards compatibility
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50] }, :resize_to => [55,55],
    :thumbnail_class => 'ImageThumbnail'
end

class ImageThumbnail < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files/thumbnails'
end

# no parent
class OrphanAttachment < ActiveRecord::Base
  has_attachment :processor => :rmagick
  validates_as_attachment
end

# no filename, no size, no content_type
class MinimalAttachment < ActiveRecord::Base
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment
  
  def filename
    "#{id}.file"
  end
end

begin
  class ImageScienceAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :image_science, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no ImageScience"
end

begin
  class CoreImageAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :core_image, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no CoreImage"
end

begin
  class MiniMagickAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no Mini Magick"
end

begin
  class GD2Attachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :gd2, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no GD2"
end


begin
  class MiniMagickAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
end

begin
  class S3Attachment < ActiveRecord::Base
    has_attachment :storage => :s3, :processor => :rmagick, :s3_config_path => File.join(File.dirname(__FILE__), '../amazon_s3.yml')
    validates_as_attachment
  end

  class S3WithPathPrefixAttachment < S3Attachment
    has_attachment :storage => :s3, :path_prefix => 'some/custom/path/prefix', :processor => :rmagick
    validates_as_attachment
  end
rescue
  puts "S3 error: #{$!}"
end
