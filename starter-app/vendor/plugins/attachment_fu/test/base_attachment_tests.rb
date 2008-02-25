module BaseAttachmentTests
  def test_should_create_file_from_uploaded_file
    assert_created do
      attachment = upload_file :filename => '/files/foo.txt'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
      #assert_equal 3, attachment.size
      assert_nil      attachment.width
      assert_nil      attachment.height
    end
  end
  
  def test_reassign_attribute_data
    assert_created 1 do
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.size > 0, "no data was set"
      
      attachment.temp_data = 'wtf'
      assert attachment.save_attachment?
      attachment.save!
      
      assert_equal 'wtf', attachment_model.find(attachment.id).send(:current_data)
    end
  end
  
  def test_no_reassign_attribute_data_on_nil
    assert_created 1 do
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.size > 0, "no data was set"
      
      attachment.temp_data = nil
      assert !attachment.save_attachment?
    end
  end
  
  def test_should_overwrite_old_contents_when_updating
    attachment   = upload_file :filename => '/files/rails.png'
    assert_not_created do # no new db_file records
      use_temp_file 'files/rails.png' do |file|
        attachment.filename = 'rails2.png'
        attachment.temp_path = File.join(fixture_path, file)
        attachment.save!
      end
    end
  end
  
  def test_should_save_without_updating_file
    attachment = upload_file :filename => '/files/foo.txt'
    assert_valid attachment
    assert !attachment.save_attachment?
    assert_nothing_raised { attachment.save! }
  end
end