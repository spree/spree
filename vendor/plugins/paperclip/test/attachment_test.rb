require 'test/helper'

class Dummy
  # This is a dummy class
end

class AttachmentTest < Test::Unit::TestCase
  context "Attachment default_options" do
    setup do
      rebuild_model
      @old_default_options = Paperclip::Attachment.default_options.dup
      @new_default_options = @old_default_options.merge({
        :path => "argle/bargle",
        :url => "fooferon",
        :default_url => "not here.png"
      })
    end

    teardown do
      Paperclip::Attachment.default_options.merge! @old_default_options
    end

    should "be overrideable" do
      Paperclip::Attachment.default_options.merge!(@new_default_options)
      @new_default_options.keys.each do |key|
        assert_equal @new_default_options[key],
                     Paperclip::Attachment.default_options[key]
      end
    end

    context "without an Attachment" do
      setup do
        @dummy = Dummy.new
      end
      
      should "return false when asked exists?" do
        assert !@dummy.avatar.exists?
      end
    end

    context "on an Attachment" do
      setup do
        @dummy = Dummy.new
        @attachment = @dummy.avatar
      end

      Paperclip::Attachment.default_options.keys.each do |key|
        should "be the default_options for #{key}" do
          assert_equal @old_default_options[key], 
                       @attachment.instance_variable_get("@#{key}"),
                       key
        end
      end

      context "when redefined" do
        setup do
          Paperclip::Attachment.default_options.merge!(@new_default_options)
          @dummy = Dummy.new
          @attachment = @dummy.avatar
        end

        Paperclip::Attachment.default_options.keys.each do |key|
          should "be the new default_options for #{key}" do
            assert_equal @new_default_options[key],
                         @attachment.instance_variable_get("@#{key}"),
                         key
          end
        end
      end
    end
  end

  context "An attachment with similarly named interpolations" do
    setup do
      rebuild_model :path => ":id.omg/:id-bbq/:idwhat/:id_partition.wtf"
      @dummy = Dummy.new
      @dummy.stubs(:id).returns(1024)
      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"))
      @dummy.avatar = @file
    end

    should "make sure that they are interpolated correctly" do
      assert_equal "1024.omg/1024-bbq/1024what/000/001/024.wtf", @dummy.avatar.path
    end
  end

  context "An attachment with a :rails_env interpolation" do
    setup do
      @rails_env = "blah"
      @id = 1024
      rebuild_model :path => ":rails_env/:id.png"
      @dummy = Dummy.new
      @dummy.stubs(:id).returns(@id)
      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"))
      @dummy.avatar = @file
    end

    should "return the proper path" do
      temporary_rails_env(@rails_env) {
        assert_equal "#{@rails_env}/#{@id}.png", @dummy.avatar.path
      }
    end
  end

  context "An attachment with :convert_options" do
    setup do
      rebuild_model :styles => {
                      :thumb => "100x100",
                      :large => "400x400"
                    },
                    :convert_options => {
                      :all => "-do_stuff",
                      :thumb => "-thumbnailize"
                    }
      @dummy = Dummy.new
    end

    should "report the correct options when sent #extra_options_for(:thumb)" do
      assert_equal "-thumbnailize -do_stuff", @dummy.avatar.send(:extra_options_for, :thumb), @dummy.avatar.convert_options.inspect
    end

    should "report the correct options when sent #extra_options_for(:large)" do
      assert_equal "-do_stuff", @dummy.avatar.send(:extra_options_for, :large)
    end

    context "when given a file" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__),
                                   "fixtures",
                                   "5k.png"))
        Paperclip::Thumbnail.stubs(:make)
        [:thumb, :large].each do |style|
          @dummy.avatar.stubs(:extra_options_for).with(style)
        end
      end

      [:thumb, :large].each do |style|
        should "call extra_options_for(#{style})" do
          @dummy.avatar.expects(:extra_options_for).with(style)
          @dummy.avatar = @file
        end
      end
    end
  end

  context "Assigning an attachment" do
    setup do
      rebuild_model
      
      @not_file = mock
      @not_file.stubs(:nil?).returns(false)
      @not_file.expects(:to_tempfile).returns(self)
      @not_file.expects(:original_filename).returns("filename.png\r\n")
      @not_file.expects(:content_type).returns("image/png\r\n")
      @not_file.expects(:size).returns(10).times(2)
      
      @dummy = Dummy.new
      @attachment = @dummy.avatar
      @attachment.expects(:valid_assignment?).with(@not_file).returns(true)
      @attachment.expects(:queue_existing_for_delete)
      @attachment.expects(:post_process)
      @attachment.expects(:validate)
      @dummy.avatar = @not_file
    end

    should "strip whitespace from original_filename field" do
      assert_equal "filename.png", @dummy.avatar.original_filename
    end

    should "strip whitespace from content_type field" do
      assert_equal "image/png", @dummy.avatar.instance.avatar_content_type
    end
    
  end

  context "Attachment with strange letters" do
    setup do
      rebuild_model
      
      @not_file = mock
      @not_file.stubs(:nil?).returns(false)
      @not_file.expects(:to_tempfile).returns(self)
      @not_file.expects(:original_filename).returns("sheep_say_bæ.png\r\n")
      @not_file.expects(:content_type).returns("image/png\r\n")
      @not_file.expects(:size).returns(10).times(2)
      
      @dummy = Dummy.new
      @attachment = @dummy.avatar
      @attachment.expects(:valid_assignment?).with(@not_file).returns(true)
      @attachment.expects(:queue_existing_for_delete)
      @attachment.expects(:post_process)
      @attachment.expects(:validate)
      @dummy.avatar = @not_file
    end
    
    should "remove strange letters and replace with underscore (_)" do
      assert_equal "sheep_say_b_.png", @dummy.avatar.original_filename
    end
    
  end

  context "An attachment" do
    setup do
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      rebuild_model
      @instance = Dummy.new
      @attachment = Paperclip::Attachment.new(:avatar, @instance)
      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"))
    end

    should "raise if there are not the correct columns when you try to assign" do
      @other_attachment = Paperclip::Attachment.new(:not_here, @instance)
      assert_raises(Paperclip::PaperclipError) do
        @other_attachment.assign(@file)
      end
    end

    should "return its default_url when no file assigned" do
      assert @attachment.to_file.nil?
      assert_equal "/avatars/original/missing.png", @attachment.url
      assert_equal "/avatars/blah/missing.png", @attachment.url(:blah)
    end
    
    context "with a file assigned in the database" do
      setup do
        @instance.stubs(:[]).with(:avatar_file_name).returns("5k.png")
        @instance.stubs(:[]).with(:avatar_content_type).returns("image/png")
        @instance.stubs(:[]).with(:avatar_file_size).returns(12345)
        now = Time.now
        Time.stubs(:now).returns(now)
        @instance.stubs(:[]).with(:avatar_updated_at).returns(Time.now)
      end

      should "return a correct url even if the file does not exist" do
        assert_nil @attachment.to_file
        assert_match %r{^/avatars/#{@instance.id}/blah/5k\.png}, @attachment.url(:blah)
      end

      should "make sure the updated_at mtime is in the url if it is defined" do
        assert_match %r{#{Time.now.to_i}$}, @attachment.url(:blah)
      end

      context "with the updated_at field removed" do
        setup do
          @instance.stubs(:[]).with(:avatar_updated_at).returns(nil)
        end

        should "only return the url without the updated_at when sent #url" do
          assert_match "/avatars/#{@instance.id}/blah/5k.png", @attachment.url(:blah)
        end
      end

      should "return the proper path when filename has a single .'s" do
        assert_equal "./test/../tmp/avatars/dummies/original/#{@instance.id}/5k.png", @attachment.path
      end

      should "return the proper path when filename has multiple .'s" do
        @instance.stubs(:[]).with(:avatar_file_name).returns("5k.old.png")      
        assert_equal "./test/../tmp/avatars/dummies/original/#{@instance.id}/5k.old.png", @attachment.path
      end

      context "when expecting three styles" do
        setup do
          styles = {:styles => { :large  => ["400x400", :png],
                                 :medium => ["100x100", :gif],
                                 :small => ["32x32#", :jpg]}}
          @attachment = Paperclip::Attachment.new(:avatar,
                                                  @instance,
                                                  styles)
        end

        context "and assigned a file" do
          setup do
            now = Time.now
            Time.stubs(:now).returns(now)
            @attachment.assign(@file)
          end

          should "be dirty" do
            assert @attachment.dirty?
          end

          context "and saved" do
            setup do
              @attachment.save
            end

            should "return the real url" do
              assert @attachment.to_file
              assert_match %r{^/avatars/#{@instance.id}/original/5k\.png}, @attachment.url
              assert_match %r{^/avatars/#{@instance.id}/small/5k\.jpg}, @attachment.url(:small)
            end

            should "commit the files to disk" do
              [:large, :medium, :small].each do |style|
                io = @attachment.to_io(style)
                assert File.exists?(io)
                assert ! io.is_a?(::Tempfile)
              end
            end

            should "save the files as the right formats and sizes" do
              [[:large, 400, 61, "PNG"],
               [:medium, 100, 15, "GIF"],
               [:small, 32, 32, "JPEG"]].each do |style|
                cmd = "identify -format '%w %h %b %m' " + 
                      "#{@attachment.to_io(style.first).path}"
                out = `#{cmd}`
                width, height, size, format = out.split(" ")
                assert_equal style[1].to_s, width.to_s 
                assert_equal style[2].to_s, height.to_s
                assert_equal style[3].to_s, format.to_s
              end
            end

            should "still have its #file attribute not be nil" do
              assert ! @attachment.to_file.nil?
            end

            context "and deleted" do
              setup do
                @existing_names = @attachment.styles.keys.collect do |style|
                  @attachment.path(style)
                end
                @instance.expects(:[]=).with(:avatar_file_name, nil)
                @instance.expects(:[]=).with(:avatar_content_type, nil)
                @instance.expects(:[]=).with(:avatar_file_size, nil)
                @instance.expects(:[]=).with(:avatar_updated_at, nil)
                @attachment.assign nil
                @attachment.save
              end

              should "delete the files" do
                @existing_names.each{|f| assert ! File.exists?(f) }
              end
            end
          end
        end
      end

    end

    context "when trying a nonexistant storage type" do
      setup do
        rebuild_model :storage => :not_here
      end

      should "not be able to find the module" do
        assert_raise(NameError){ Dummy.new.avatar }
      end
    end
  end
end
