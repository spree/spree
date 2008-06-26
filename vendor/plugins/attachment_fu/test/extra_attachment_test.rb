require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class OrphanAttachmentTest < Test::Unit::TestCase
  include BaseAttachmentTests
  attachment_model OrphanAttachment
  
  def test_should_create_image_from_uploaded_file
    assert_created do
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
    end
  end
  
  def test_should_create_file_from_uploaded_file
    assert_created do
      attachment = upload_file :filename => '/files/foo.txt'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
    end
  end
  
  def test_should_create_file_from_merb_temp_file
    assert_created do
      attachment = upload_merb_file :filename => '/files/foo.txt'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
    end
  end
  
  def test_should_create_image_from_uploaded_file_with_custom_content_type
    assert_created do
      attachment = upload_file :content_type => 'foo/bar', :filename => '/files/rails.png'
      assert_valid attachment
      assert !attachment.image?
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert !attachment.size.zero?
      #assert_equal 1784, attachment.size
    end
  end
  
  def test_should_create_thumbnail
    attachment = upload_file :filename => '/files/rails.png'
    
    assert_raise Technoweenie::AttachmentFu::ThumbnailError do
      attachment.create_or_update_thumbnail(attachment.create_temp_file, 'thumb', 50, 50)
    end
  end
  
  def test_should_create_thumbnail_with_geometry_string
   attachment = upload_file :filename => '/files/rails.png'
    
    assert_raise Technoweenie::AttachmentFu::ThumbnailError do
      attachment.create_or_update_thumbnail(attachment.create_temp_file, 'thumb', 'x50')
    end
  end
end

class MinimalAttachmentTest < OrphanAttachmentTest
  attachment_model MinimalAttachment
end