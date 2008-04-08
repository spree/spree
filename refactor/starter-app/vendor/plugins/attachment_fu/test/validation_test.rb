require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class ValidationTest < Test::Unit::TestCase
  def test_should_invalidate_big_files
    @attachment = SmallAttachment.new
    assert !@attachment.valid?
    assert @attachment.errors.on(:size)
    
    @attachment.size = 2000
    assert !@attachment.valid?
    assert @attachment.errors.on(:size), @attachment.errors.full_messages.to_sentence
    
    @attachment.size = 1000
    assert !@attachment.valid?
    assert_nil @attachment.errors.on(:size)
  end

  def test_should_invalidate_small_files
    @attachment = BigAttachment.new
    assert !@attachment.valid?
    assert @attachment.errors.on(:size)
    
    @attachment.size = 2000
    assert !@attachment.valid?
    assert @attachment.errors.on(:size), @attachment.errors.full_messages.to_sentence
    
    @attachment.size = 1.megabyte
    assert !@attachment.valid?
    assert_nil @attachment.errors.on(:size)
  end
  
  def test_should_validate_content_type
    @attachment = PdfAttachment.new
    assert !@attachment.valid?
    assert @attachment.errors.on(:content_type)

    @attachment.content_type = 'foo'
    assert !@attachment.valid?
    assert @attachment.errors.on(:content_type)

    @attachment.content_type = 'pdf'
    assert !@attachment.valid?
    assert_nil @attachment.errors.on(:content_type)
  end

  def test_should_require_filename
    @attachment = Attachment.new
    assert !@attachment.valid?
    assert @attachment.errors.on(:filename)
    
    @attachment.filename = 'foo'
    assert !@attachment.valid?
    assert_nil @attachment.errors.on(:filename)
  end
end