require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class MiniMagickTest < Test::Unit::TestCase
  attachment_model MiniMagickAttachment

  if Object.const_defined?(:MiniMagick)
    def test_should_resize_image
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.image?
      # test MiniMagick thumbnail
      assert_equal 43, attachment.width
      assert_equal 55, attachment.height
      
      thumb      = attachment.thumbnails.detect { |t| t.filename =~ /_thumb/ }
      geo        = attachment.thumbnails.detect { |t| t.filename =~ /_geometry/ }
      
      # test exact resize dimensions
      assert_equal 50, thumb.width
      assert_equal 51, thumb.height
      
      # test geometry string
      assert_equal 31, geo.width
      assert_equal 40, geo.height
    end
  else
    def test_flunk
      puts "MiniMagick not loaded, tests not running"
    end
  end
end
