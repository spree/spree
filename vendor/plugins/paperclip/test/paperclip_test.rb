require 'test/helper.rb'

class PaperclipTest < Test::Unit::TestCase
  context "Calling Paperclip.run" do
    should "execute the right command" do
      Paperclip.expects(:path_for_command).with("convert").returns("/usr/bin/convert")
      Paperclip.expects(:bit_bucket).returns("/dev/null")
      Paperclip.expects(:"`").with("/usr/bin/convert one.jpg two.jpg 2>/dev/null")
      Paperclip.run("convert", "one.jpg two.jpg")
    end
  end

  context "Paperclip.bit_bucket" do
    context "on systems without /dev/null" do
      setup do
        File.expects(:exists?).with("/dev/null").returns(false)
      end
      
      should "return 'NUL'" do
        assert_equal "NUL", Paperclip.bit_bucket
      end
    end

    context "on systems with /dev/null" do
      setup do
        File.expects(:exists?).with("/dev/null").returns(true)
      end
      
      should "return '/dev/null'" do
        assert_equal "/dev/null", Paperclip.bit_bucket
      end
    end
  end

  context "An ActiveRecord model with an 'avatar' attachment" do
    setup do
      rebuild_model :path => "tmp/:class/omg/:style.:extension"
      @file = File.new(File.join(FIXTURES_DIR, "5k.png"))
    end

    should "not error when trying to also create a 'blah' attachment" do
      assert_nothing_raised do
        Dummy.class_eval do
          has_attached_file :blah
        end
      end
    end

    context "that is attr_protected" do
      setup do
        Dummy.class_eval do
          attr_protected :avatar
        end
        @dummy = Dummy.new
      end

      should "not assign the avatar on mass-set" do
        @dummy.logger.expects(:debug)

        @dummy.attributes = { :other => "I'm set!",
                              :avatar => @file }
        
        assert_equal "I'm set!", @dummy.other
        assert ! @dummy.avatar?
      end

      should "still allow assigment on normal set" do
        @dummy.logger.expects(:debug).times(0)

        @dummy.other  = "I'm set!"
        @dummy.avatar = @file
        
        assert_equal "I'm set!", @dummy.other
        assert @dummy.avatar?
      end
    end

    context "with a subclass" do
      setup do
        class ::SubDummy < Dummy; end
      end

      should "be able to use the attachment from the subclass" do
        assert_nothing_raised do
          @subdummy = SubDummy.create(:avatar => @file)
        end
      end

      should "be able to see the attachment definition from the subclass's class" do
        assert_equal "tmp/:class/omg/:style.:extension", SubDummy.attachment_definitions[:avatar][:path]
      end

      teardown do
        Object.send(:remove_const, "SubDummy") rescue nil
      end
    end

    should "have an #avatar method" do
      assert Dummy.new.respond_to?(:avatar)
    end

    should "have an #avatar= method" do
      assert Dummy.new.respond_to?(:avatar=)
    end

    context "that is valid" do
      setup do
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "be valid" do
        assert @dummy.valid?
      end

      context "then has a validation added that makes it invalid" do
        setup do
          assert @dummy.save
          Dummy.class_eval do
            validates_attachment_content_type :avatar, :content_type => ["text/plain"]
          end
          @dummy2 = Dummy.find(@dummy.id)
        end

        should "be invalid when reloaded" do
          assert ! @dummy2.valid?, @dummy2.errors.inspect
        end

        should "be able to call #valid? twice without having duplicate errors" do
          @dummy2.avatar.valid?
          first_errors = @dummy2.avatar.errors
          @dummy2.avatar.valid?
          assert_equal first_errors, @dummy2.avatar.errors
        end
      end
    end

    [[:presence,      nil,                             "5k.png",   nil],
     [:size,          {:in => 1..10240},               "5k.png",   "12k.png"],
     [:size2,         {:in => 1..10240},               nil,        "12k.png"],
     [:content_type1, {:content_type => "image/png"},  "5k.png",   "text.txt"],
     [:content_type2, {:content_type => "text/plain"}, "text.txt", "5k.png"],
     [:content_type3, {:content_type => %r{image/.*}}, "5k.png",   "text.txt"],
     [:content_type4, {:content_type => "image/png"},  nil,        "text.txt"]].each do |args|
      context "with #{args[0]} validations" do
        setup do
          Dummy.class_eval do
            send(*[:"validates_attachment_#{args[0].to_s[/[a-z_]*/]}", :avatar, args[1]].compact)
          end
          @dummy = Dummy.new
        end

        context "and a valid file" do
          setup do
            @file = args[2] && File.new(File.join(FIXTURES_DIR, args[2]))
          end

          should "not have any errors" do
            @dummy.avatar = @file
            assert @dummy.avatar.valid?
            assert_equal 0, @dummy.avatar.errors.length
          end
        end

        context "and an invalid file" do
          setup do
            @file = args[3] && File.new(File.join(FIXTURES_DIR, args[3]))
          end

          should "have errors" do
            @dummy.avatar = @file
            assert ! @dummy.avatar.valid?
            assert_equal 1, @dummy.avatar.errors.length
          end
        end
      end
    end
  end
end
