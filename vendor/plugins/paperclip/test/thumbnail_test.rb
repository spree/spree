require 'test/helper'

class ThumbnailTest < Test::Unit::TestCase

  context "A Paperclip Tempfile" do
    setup do
      @tempfile = Paperclip::Tempfile.new("file.jpg")
    end

    should "have its path contain a real extension" do
      assert_equal ".jpg", File.extname(@tempfile.path)
    end

    should "be a real Tempfile" do
      assert @tempfile.is_a?(::Tempfile)
    end
  end

  context "Another Paperclip Tempfile" do
    setup do
      @tempfile = Paperclip::Tempfile.new("file")
    end

    should "not have an extension if not given one" do
      assert_equal "", File.extname(@tempfile.path)
    end

    should "still be a real Tempfile" do
      assert @tempfile.is_a?(::Tempfile)
    end
  end

  context "An image" do
    setup do
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
    end

    teardown { @file.close }

    [["600x600>", "434x66"],
     ["400x400>", "400x61"],
     ["32x32<", "434x66"]
    ].each do |args|
      context "being thumbnailed with a geometry of #{args[0]}" do
        setup do
          @thumb = Paperclip::Thumbnail.new(@file, :geometry => args[0])
        end

        should "start with dimensions of 434x66" do
          cmd = %Q[identify -format "%wx%h" "#{@file.path}"] 
          assert_equal "434x66", `#{cmd}`.chomp
        end

        should "report the correct target geometry" do
          assert_equal args[0], @thumb.target_geometry.to_s
        end

        context "when made" do
          setup do
            @thumb_result = @thumb.make
          end

          should "be the size we expect it to be" do
            cmd = %Q[identify -format "%wx%h" "#{@thumb_result.path}"] 
            assert_equal args[1], `#{cmd}`.chomp
          end
        end
      end
    end

    context "being thumbnailed at 100x50 with cropping" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x50#")
      end

      should "report its correct current and target geometries" do
        assert_equal "100x50#", @thumb.target_geometry.to_s
        assert_equal "434x66", @thumb.current_geometry.to_s
      end

      should "report its correct format" do
        assert_nil @thumb.format
      end

      should "have whiny turned on by default" do
        assert @thumb.whiny
      end
      
      should "have convert_options set to nil by default" do
        assert_equal nil, @thumb.convert_options
      end

      should "send the right command to convert when sent #make" do
        Paperclip.expects(:"`").with do |arg|
          arg.match %r{convert\s+"#{File.expand_path(@thumb.file.path)}\[0\]"\s+-resize\s+\"x50\"\s+-crop\s+\"100x50\+114\+0\"\s+\+repage\s+".*?"}
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x50/, `identify "#{dst.path}"`
      end
    end
    
    context "being thumbnailed with convert options set" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file,
                                          :geometry        => "100x50#",
                                          :convert_options => "-strip -depth 8")
      end

      should "have convert_options value set" do
        assert_equal "-strip -depth 8", @thumb.convert_options
      end

      should "send the right command to convert when sent #make" do
        Paperclip.expects(:"`").with do |arg|
          arg.match %r{convert\s+"#{File.expand_path(@thumb.file.path)}\[0\]"\s+-resize\s+"x50"\s+-crop\s+"100x50\+114\+0"\s+\+repage\s+-strip\s+-depth\s+8\s+".*?"}
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x50/, `identify "#{dst.path}"`
      end
      
      context "redefined to have bad convert_options setting" do
        setup do
          @thumb = Paperclip::Thumbnail.new(@file,
                                            :geometry => "100x50#",
                                            :convert_options => "-this-aint-no-option")
        end

        should "error when trying to create the thumbnail" do
          assert_raises(Paperclip::PaperclipError) do
            @thumb.make
          end
        end
      end      
    end
  end

  context "A multipage PDF" do
    setup do
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "twopage.pdf"), 'rb')
    end

    teardown { @file.close }

    should "start with two pages with dimensions 612x792" do
      cmd = %Q[identify -format "%wx%h" "#{@file.path}"] 
      assert_equal "612x792"*2, `#{cmd}`.chomp
    end

    context "being thumbnailed at 100x100 with cropping" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x100#", :format => :png)
      end

      should "report its correct current and target geometries" do
        assert_equal "100x100#", @thumb.target_geometry.to_s
        assert_equal "612x792", @thumb.current_geometry.to_s
      end

      should "report its correct format" do
        assert_equal :png, @thumb.format
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x100/, `identify "#{dst.path}"`
      end
    end
  end
end
