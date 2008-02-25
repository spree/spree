require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class RmagickTest < Test::Unit::TestCase
  attachment_model Attachment

  if Object.const_defined?(:Magick)
    def test_should_create_image_from_uploaded_file
      assert_created do
        attachment = upload_file :filename => '/files/rails.png'
        assert_valid attachment
        assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
        assert  attachment.image?
        assert !attachment.size.zero?
        #assert_equal 1784, attachment.size
        assert_equal 50,   attachment.width
        assert_equal 64,   attachment.height
        assert_equal '50x64', attachment.image_size
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
        assert_nil attachment.width
        assert_nil attachment.height
        assert_equal [], attachment.thumbnails
      end
    end
    
    def test_should_create_thumbnail
      attachment = upload_file :filename => '/files/rails.png'
      
      assert_created do
        basename, ext = attachment.filename.split '.'
        thumbnail = attachment.create_or_update_thumbnail(attachment.create_temp_file, 'thumb', 50, 50)
        assert_valid thumbnail
        assert !thumbnail.size.zero?
        #assert_in_delta 4673, thumbnail.size, 2
        assert_equal 50,   thumbnail.width
        assert_equal 50,   thumbnail.height
        assert_equal [thumbnail.id], attachment.thumbnails.collect(&:id)
        assert_equal attachment.id,  thumbnail.parent_id if thumbnail.respond_to?(:parent_id)
        assert_equal "#{basename}_thumb.#{ext}", thumbnail.filename
      end
    end
    
    def test_should_create_thumbnail_with_geometry_string
      attachment = upload_file :filename => '/files/rails.png'
      
      assert_created do
        basename, ext = attachment.filename.split '.'
        thumbnail = attachment.create_or_update_thumbnail(attachment.create_temp_file, 'thumb', 'x50')
        assert_valid thumbnail
        assert !thumbnail.size.zero?
        #assert_equal 3915, thumbnail.size
        assert_equal 39,   thumbnail.width
        assert_equal 50,   thumbnail.height
        assert_equal [thumbnail], attachment.thumbnails
        assert_equal attachment.id,  thumbnail.parent_id if thumbnail.respond_to?(:parent_id)
        assert_equal "#{basename}_thumb.#{ext}", thumbnail.filename
      end
    end
    
    def test_should_resize_image(klass = ImageAttachment)
      attachment_model klass
      assert_equal [50, 50], attachment_model.attachment_options[:resize_to]
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
      #assert_in_delta 4673, attachment.size, 2
      assert_equal 50, attachment.width
      assert_equal 50, attachment.height
    end
    
    test_against_subclass :test_should_resize_image, ImageAttachment
    
    def test_should_resize_image_with_geometry(klass = ImageOrPdfAttachment)
      attachment_model klass
      assert_equal 'x50', attachment_model.attachment_options[:resize_to]
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
      #assert_equal 3915, attachment.size
      assert_equal 39,   attachment.width
      assert_equal 50,   attachment.height
    end
    
    test_against_subclass :test_should_resize_image_with_geometry, ImageOrPdfAttachment
    
    def test_should_give_correct_thumbnail_filenames(klass = ImageWithThumbsFileAttachment)
      attachment_model klass
      assert_created 3 do
        attachment = upload_file :filename => '/files/rails.png'
        thumb      = attachment.thumbnails.detect { |t| t.filename =~ /_thumb/ }
        geo        = attachment.thumbnails.detect { |t| t.filename =~ /_geometry/ }
        
        [attachment, thumb, geo].each { |record| assert_valid record }
    
        assert_match /rails\.png$/,          attachment.full_filename
        assert_match /rails_geometry\.png$/, attachment.full_filename(:geometry)
        assert_match /rails_thumb\.png$/,    attachment.full_filename(:thumb)
      end
    end
    
    test_against_subclass :test_should_give_correct_thumbnail_filenames, ImageWithThumbsFileAttachment
    
    def test_should_automatically_create_thumbnails(klass = ImageWithThumbsAttachment)
      attachment_model klass
      assert_created 3 do
        attachment = upload_file :filename => '/files/rails.png'
        assert_valid attachment
        assert !attachment.size.zero?
        #assert_equal 1784, attachment.size
        assert_equal 55,   attachment.width
        assert_equal 55,   attachment.height
        assert_equal 2,    attachment.thumbnails.length
        assert_equal 1.0,  attachment.aspect_ratio
        
        thumb = attachment.thumbnails.detect { |t| t.filename =~ /_thumb/ }
        assert !thumb.new_record?, thumb.errors.full_messages.join("\n")
        assert !thumb.size.zero?
        #assert_in_delta 4673, thumb.size, 2
        assert_equal 50,   thumb.width
        assert_equal 50,   thumb.height
        assert_equal 1.0,  thumb.aspect_ratio
        
        geo   = attachment.thumbnails.detect { |t| t.filename =~ /_geometry/ }
        assert !geo.new_record?, geo.errors.full_messages.join("\n")
        assert !geo.size.zero?
        #assert_equal 3915, geo.size
        assert_equal 50,   geo.width
        assert_equal 50,   geo.height
        assert_equal 1.0,  geo.aspect_ratio
      end
    end
    
    test_against_subclass :test_should_automatically_create_thumbnails, ImageWithThumbsAttachment
    
    # same as above method, but test it on a file model
    test_against_class :test_should_automatically_create_thumbnails, ImageWithThumbsFileAttachment
    test_against_subclass :test_should_automatically_create_thumbnails_on_class, ImageWithThumbsFileAttachment
    
    def test_should_use_thumbnail_subclass(klass = ImageWithThumbsClassFileAttachment)
      attachment_model klass
      attachment = nil
      assert_difference ImageThumbnail, :count do
        attachment = upload_file :filename => '/files/rails.png'
        assert_valid attachment
      end
      assert_kind_of ImageThumbnail,  attachment.thumbnails.first
      assert_equal attachment.id,     attachment.thumbnails.first.parent.id
      assert_kind_of FileAttachment,  attachment.thumbnails.first.parent
      assert_equal 'rails_thumb.png', attachment.thumbnails.first.filename
      assert_equal attachment.thumbnails.first.full_filename, attachment.full_filename(attachment.thumbnails.first.thumbnail),
        "#full_filename does not use thumbnail class' path."
      assert_equal attachment.destroy attachment
    end
    
    test_against_subclass :test_should_use_thumbnail_subclass, ImageWithThumbsClassFileAttachment
    
    def test_should_remove_old_thumbnail_files_when_updating(klass = ImageWithThumbsFileAttachment)
      attachment_model klass
      attachment = nil
      assert_created 3 do
        attachment = upload_file :filename => '/files/rails.png'
      end
    
      old_filenames = [attachment.full_filename] + attachment.thumbnails.collect(&:full_filename)
    
      assert_not_created do
        use_temp_file "files/rails.png" do |file|
          attachment.filename        = 'rails2.png'
          attachment.temp_path = File.join(fixture_path, file)
          attachment.save
          new_filenames = [attachment.reload.full_filename] + attachment.thumbnails.collect { |t| t.reload.full_filename }
          new_filenames.each { |f| assert  File.exists?(f), "#{f} does not exist" }
          old_filenames.each { |f| assert !File.exists?(f), "#{f} still exists" }
        end
      end
    end
    
    test_against_subclass :test_should_remove_old_thumbnail_files_when_updating, ImageWithThumbsFileAttachment
    
    def test_should_delete_file_when_in_file_system_when_attachment_record_destroyed(klass = ImageWithThumbsFileAttachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      filenames = [attachment.full_filename] + attachment.thumbnails.collect(&:full_filename)
      filenames.each { |f| assert  File.exists?(f),  "#{f} never existed to delete on destroy" }
      attachment.destroy
      filenames.each { |f| assert !File.exists?(f),  "#{f} still exists" }
    end
    
    test_against_subclass :test_should_delete_file_when_in_file_system_when_attachment_record_destroyed, ImageWithThumbsFileAttachment
    
    def test_should_overwrite_old_thumbnail_records_when_updating(klass = ImageWithThumbsAttachment)
      attachment_model klass
      attachment = nil
      assert_created 3 do
        attachment = upload_file :filename => '/files/rails.png'
      end
      assert_not_created do # no new db_file records
        use_temp_file "files/rails.png" do |file|
          attachment.filename             = 'rails2.png'
          attachment.temp_path = File.join(fixture_path, file)
          attachment.save!
        end
      end
    end
    
    test_against_subclass :test_should_overwrite_old_thumbnail_records_when_updating, ImageWithThumbsAttachment
    
    def test_should_overwrite_old_thumbnail_records_when_renaming(klass = ImageWithThumbsAttachment)
      attachment_model klass
      attachment = nil
      assert_created 3 do
        attachment = upload_file :class => klass, :filename => '/files/rails.png'
      end
      assert_not_created do # no new db_file records
        attachment.filename = 'rails2.png'
        attachment.save
        assert !attachment.reload.size.zero?
        assert_equal 'rails2.png', attachment.filename
      end
    end
    
    test_against_subclass :test_should_overwrite_old_thumbnail_records_when_renaming, ImageWithThumbsAttachment
  else
    def test_flunk
      puts "RMagick not installed, no tests running"
    end
  end
end