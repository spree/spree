require 'test/helper.rb'

class IntegrationTest < Test::Unit::TestCase
  context "Many models at once" do
    setup do
      rebuild_model
      @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
      300.times do |i|
        Dummy.create! :avatar => @file
      end
    end
    
    should "not exceed the open file limit" do
       assert_nothing_raised do
         dummies = Dummy.find(:all)
         dummies.each { |dummy| dummy.avatar }
       end
    end
  end

  context "An attachment" do
    setup do
      rebuild_model :styles => { :thumb => "50x50#" }
      @dummy = Dummy.new
      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"))
      @dummy.avatar = @file
      assert @dummy.save
    end

    should "create its thumbnails properly" do
      assert_match /\b50x50\b/, `identify '#{@dummy.avatar.path(:thumb)}'`
    end

    context "redefining its attachment styles" do
      setup do
        Dummy.class_eval do
          has_attached_file :avatar, :styles => { :thumb => "150x25#" }
        end
        @d2 = Dummy.find(@dummy.id)
        @d2.avatar.reprocess!
        @d2.save
      end

      should "create its thumbnails properly" do
        assert_match /\b150x25\b/, `identify '#{@dummy.avatar.path(:thumb)}'`
      end
    end
  end

  context "A model with no attachment validation" do
    setup do
      rebuild_model :styles => { :large => "300x300>",
                                 :medium => "100x100",
                                 :thumb => ["32x32#", :gif] },
                    :default_style => :medium,
                    :url => "/:attachment/:class/:style/:id/:basename.:extension",
                    :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      @dummy     = Dummy.new
    end

    should "have its definition return false when asked about whiny_thumbnails" do
      assert ! Dummy.attachment_definitions[:avatar][:whiny_thumbnails]
    end

    context "when validates_attachment_thumbnails is called" do
      setup do
        Dummy.validates_attachment_thumbnails :avatar
      end

      should "have its definition return true when asked about whiny_thumbnails" do
        assert_equal true, Dummy.attachment_definitions[:avatar][:whiny_thumbnails]
      end
    end

    context "redefined to have attachment validations" do
      setup do
        rebuild_model :styles => { :large => "300x300>",
                                   :medium => "100x100",
                                   :thumb => ["32x32#", :gif] },
                      :whiny_thumbnails => true,
                      :default_style => :medium,
                      :url => "/:attachment/:class/:style/:id/:basename.:extension",
                      :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      end

      should "have its definition return true when asked about whiny_thumbnails" do
        assert_equal true, Dummy.attachment_definitions[:avatar][:whiny_thumbnails]
      end
    end
  end
  
  context "A model with no thumbnail_convert_options setting" do
    setup do
      rebuild_model :styles => { :large => "300x300>",
                                 :medium => "100x100",
                                 :thumb => ["32x32#", :gif] },
                    :default_style => :medium,
                    :url => "/:attachment/:class/:style/:id/:basename.:extension",
                    :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      @dummy     = Dummy.new
    end
    
    should "have its definition return nil when asked about convert_options" do
      assert ! Dummy.attachment_definitions[:avatar][:thumbnail_convert_options]
    end

    context "redefined to have convert_options setting" do
      setup do
        rebuild_model :styles => { :large => "300x300>",
                                   :medium => "100x100",
                                   :thumb => ["32x32#", :gif] },
                      :thumbnail_convert_options => "-strip -depth 8",
                      :default_style => :medium,
                      :url => "/:attachment/:class/:style/:id/:basename.:extension",
                      :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      end

      should "have its definition return convert_options value when asked about convert_options" do
        assert_equal "-strip -depth 8", Dummy.attachment_definitions[:avatar][:thumbnail_convert_options]
      end
    end
  end
  
  context "A model with a filesystem attachment" do
    setup do
      rebuild_model :styles => { :large => "300x300>",
                                 :medium => "100x100",
                                 :thumb => ["32x32#", :gif] },
                    :whiny_thumbnails => true,
                    :default_style => :medium,
                    :url => "/:attachment/:class/:style/:id/:basename.:extension",
                    :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      @dummy     = Dummy.new
      @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
      @bad_file  = File.new(File.join(FIXTURES_DIR, "bad.png"))

      assert @dummy.avatar = @file
      assert @dummy.valid?
      assert @dummy.save
    end

    should "write and delete its files" do
      [["434x66", :original],
       ["300x46", :large],
       ["100x15", :medium],
       ["32x32", :thumb]].each do |geo, style|
        cmd = %Q[identify -format "%wx%h" #{@dummy.avatar.to_file(style).path}]
        assert_equal geo, `#{cmd}`.chomp, cmd
      end

      saved_paths = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s).path }

      @d2 = Dummy.find(@dummy.id)
      assert_equal "100x15", `identify -format "%wx%h" #{@d2.avatar.to_file.path}`.chomp
      assert_equal "434x66", `identify -format "%wx%h" #{@d2.avatar.to_file(:original).path}`.chomp
      assert_equal "300x46", `identify -format "%wx%h" #{@d2.avatar.to_file(:large).path}`.chomp
      assert_equal "100x15", `identify -format "%wx%h" #{@d2.avatar.to_file(:medium).path}`.chomp
      assert_equal "32x32",  `identify -format "%wx%h" #{@d2.avatar.to_file(:thumb).path}`.chomp

      @dummy.avatar = "not a valid file but not nil"
      assert_equal File.basename(@file.path), @dummy.avatar_file_name
      assert @dummy.valid?
      assert @dummy.save

      saved_paths.each do |p|
        assert File.exists?(p)
      end

      @dummy.avatar = nil
      assert_nil @dummy.avatar_file_name
      assert @dummy.valid?
      assert @dummy.save

      saved_paths.each do |p|
        assert ! File.exists?(p)
      end

      @d2 = Dummy.find(@dummy.id)
      assert_nil @d2.avatar_file_name
    end

    should "work exactly the same when new as when reloaded" do
      @d2 = Dummy.find(@dummy.id)

      assert_equal @dummy.avatar_file_name, @d2.avatar_file_name
      [:thumb, :medium, :large, :original].each do |style|
        assert_equal @dummy.avatar.to_file(style).path, @d2.avatar.to_file(style).path
      end

      saved_paths = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s).path }

      @d2.avatar = nil
      assert @d2.save

      saved_paths.each do |p|
        assert ! File.exists?(p)
      end
    end

    should "know the difference between good files, bad files, not files, and nil" do
      expected = @dummy.avatar.to_file
      @dummy.avatar = "not a file"
      assert @dummy.valid?
      assert_equal expected.path, @dummy.avatar.to_file.path

      @dummy.avatar = @bad_file
      assert ! @dummy.valid?
      @dummy.avatar = nil
      assert @dummy.valid?
    end

    should "know the difference between good files, bad files, not files, and nil when validating" do
      Dummy.validates_attachment_presence :avatar
      @d2 = Dummy.find(@dummy.id)
      @d2.avatar = @file
      assert   @d2.valid?
      @d2.avatar = @bad_file
      assert ! @d2.valid?
      @d2.avatar = nil
      assert ! @d2.valid?
    end

    should "be able to reload without saving and not have the file disappear" do
      @dummy.avatar = @file
      assert @dummy.save
      @dummy.avatar = nil
      assert_nil @dummy.avatar_file_name
      @dummy.reload
      assert_equal "5k.png", @dummy.avatar_file_name
    end
    
    context "that is assigned its file from another Paperclip attachment" do
      setup do
        @dummy2 = Dummy.new
        @file2  = File.new(File.join(FIXTURES_DIR, "12k.png"))
        assert  @dummy2.avatar = @file2
        @dummy2.save
      end
      
      should "work when assigned a file" do
        assert_not_equal `identify -format "%wx%h" #{@dummy.avatar.to_file(:original).path}`,
                         `identify -format "%wx%h" #{@dummy2.avatar.to_file(:original).path}`

        assert @dummy.avatar = @dummy2.avatar
        @dummy.save
        assert_equal `identify -format "%wx%h" #{@dummy.avatar.to_file(:original).path}`,
                     `identify -format "%wx%h" #{@dummy2.avatar.to_file(:original).path}`
      end
      
      should "work when assigned a nil file" do
        @dummy2.avatar = nil
        @dummy2.save

        @dummy.avatar = @dummy2.avatar
        @dummy.save
        
        assert !@dummy.avatar?
      end
    end    

  end

  if ENV['S3_TEST_BUCKET']
    def s3_files_for attachment
      [:thumb, :medium, :large, :original].inject({}) do |files, style|
        data = `curl '#{attachment.url(style)}' 2>/dev/null`.chomp
        t = Tempfile.new("paperclip-test")
        t.write(data)
        t.rewind
        files[style] = t
        files
      end
    end

    context "A model with an S3 attachment" do
      setup do
        rebuild_model :styles => { :large => "300x300>",
                                   :medium => "100x100",
                                   :thumb => ["32x32#", :gif] },
                      :storage => :s3,
                      :whiny_thumbnails => true,
                      # :s3_options => {:logger => Logger.new(StringIO.new)},
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "s3.yml")),
                      :default_style => :medium,
                      :bucket => ENV['S3_TEST_BUCKET'],
                      :path => ":class/:attachment/:id/:style/:basename.:extension"
        @dummy     = Dummy.new
        @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
        @bad_file  = File.new(File.join(FIXTURES_DIR, "bad.png"))

        assert @dummy.avatar = @file
        assert @dummy.valid?
        assert @dummy.save

        @files_on_s3 = s3_files_for @dummy.avatar
      end

      should "write and delete its files" do
        [["434x66", :original],
         ["300x46", :large],
         ["100x15", :medium],
         ["32x32", :thumb]].each do |geo, style|
          cmd = %Q[identify -format "%wx%h" #{@files_on_s3[style].path}]
          assert_equal geo, `#{cmd}`.chomp, cmd
        end

        @d2 = Dummy.find(@dummy.id)
        @d2_files = s3_files_for @d2.avatar
        [["434x66", :original],
         ["300x46", :large],
         ["100x15", :medium],
         ["32x32", :thumb]].each do |geo, style|
          cmd = %Q[identify -format "%wx%h" #{@d2_files[style].path}]
          assert_equal geo, `#{cmd}`.chomp, cmd
        end

        @dummy.avatar = "not a valid file but not nil"
        assert_equal File.basename(@file.path), @dummy.avatar_file_name
        assert @dummy.valid?
        assert @dummy.save

        saved_keys = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s) }

        saved_keys.each do |key|
          assert key.exists?
        end

        @dummy.avatar = nil
        assert_nil @dummy.avatar_file_name
        assert @dummy.valid?
        assert @dummy.save

        saved_keys.each do |key|
          assert ! key.exists?
        end

        @d2 = Dummy.find(@dummy.id)
        assert_nil @d2.avatar_file_name
      end

      should "work exactly the same when new as when reloaded" do
        @d2 = Dummy.find(@dummy.id)

        assert_equal @dummy.avatar_file_name, @d2.avatar_file_name
        [:thumb, :medium, :large, :original].each do |style|
          assert_equal @dummy.avatar.to_file(style).to_s, @d2.avatar.to_file(style).to_s
        end

        saved_keys = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s) }

        @d2.avatar = nil
        assert @d2.save

        saved_keys.each do |key|
          assert ! key.exists?
        end
      end

      should "know the difference between good files, bad files, not files, and nil" do
        expected = @dummy.avatar.to_file
        @dummy.avatar = "not a file"
        assert @dummy.valid?
        assert_equal expected.full_name, @dummy.avatar.to_file.full_name

        @dummy.avatar = @bad_file
        assert ! @dummy.valid?
        @dummy.avatar = nil
        assert @dummy.valid?

        Dummy.validates_attachment_presence :avatar
        @d2 = Dummy.find(@dummy.id)
        @d2.avatar = @file
        assert   @d2.valid?
        @d2.avatar = @bad_file
        assert ! @d2.valid?
        @d2.avatar = nil
        assert ! @d2.valid?
      end

      should "be able to reload without saving and not have the file disappear" do
        @dummy.avatar = @file
        assert @dummy.save
        @dummy.avatar = nil
        assert_nil @dummy.avatar_file_name
        @dummy.reload
        assert_equal "5k.png", @dummy.avatar_file_name
      end
    end
  end
end

