require 'test/helper'

class StorageTest < Test::Unit::TestCase
  context "Parsing S3 credentials" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :s3_credentials => {:not => :important}

      @dummy = Dummy.new
      @avatar = @dummy.avatar

      @current_env = RAILS_ENV
    end

    teardown do
      Object.const_set("RAILS_ENV", @current_env)
    end

    should "get the correct credentials when RAILS_ENV is production" do
      Object.const_set('RAILS_ENV', "production")
      assert_equal({:key => "12345"},
                   @avatar.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "get the correct credentials when RAILS_ENV is development" do
      Object.const_set('RAILS_ENV', "development")
      assert_equal({:key => "54321"},
                   @avatar.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "return the argument if the key does not exist" do
      Object.const_set('RAILS_ENV', "not really an env")
      assert_equal({:test => "12345"}, @avatar.parse_credentials(:test => "12345"))
    end
  end

  context "" do
    setup do
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_path_url"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an S3 path" do
      assert_match %r{^http://s3.amazonaws.com/bucket/avatars/stringio.txt}, @dummy.avatar.url
    end
  end
  context "" do
    setup do
      rebuild_model :storage => :s3,
                    :s3_credentials => {},
                    :bucket => "bucket",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_domain_url"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on an S3 subdomain" do
      assert_match %r{^http://bucket.s3.amazonaws.com/avatars/stringio.txt}, @dummy.avatar.url
    end
  end
  context "" do
    setup do
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :bucket => "prod_bucket" },
                      :development  => { :bucket => "dev_bucket" }
                    },
                    :s3_host_alias => "something.something.com",
                    :path => ":attachment/:basename.:extension",
                    :url => ":s3_alias_url"
      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")
    end

    should "return a url based on the host_alias" do
      assert_match %r{^http://something.something.com/avatars/stringio.txt}, @dummy.avatar.url
    end
  end

  context "Parsing S3 credentials with a bucket in them" do
    setup do
      rebuild_model :storage => :s3,
                    :s3_credentials => {
                      :production   => { :bucket => "prod_bucket" },
                      :development  => { :bucket => "dev_bucket" }
                    }
      @dummy = Dummy.new
      @old_env = RAILS_ENV
    end

    teardown{ Object.const_set("RAILS_ENV", @old_env) }

    should "get the right bucket in production" do
      Object.const_set("RAILS_ENV", "production")
      assert_equal "prod_bucket", @dummy.avatar.bucket_name
    end

    should "get the right bucket in development" do
      Object.const_set("RAILS_ENV", "development")
      assert_equal "dev_bucket", @dummy.avatar.bucket_name
    end
  end

  context "An attachment with S3 storage" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }
    end

    should "be extended by the S3 module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
    end

    should "not be extended by the Filesystem module" do
      assert ! Dummy.new.avatar.is_a?(Paperclip::Storage::Filesystem)
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      should "not get a bucket to get a URL" do
        @dummy.avatar.expects(:s3).never
        @dummy.avatar.expects(:s3_bucket).never
        assert_match %r{^http://s3\.amazonaws\.com/testing/avatars/original/5k\.png}, @dummy.avatar.url
      end

      context "and saved" do
        setup do
          @s3_mock     = stub
          @bucket_mock = stub
          RightAws::S3.expects(:new).with("12345", "54321", {}).returns(@s3_mock)
          @s3_mock.expects(:bucket).with("testing", true, "public-read").returns(@bucket_mock)
          @key_mock = stub
          @bucket_mock.expects(:key).returns(@key_mock)
          @key_mock.expects(:data=)
          @key_mock.expects(:put).with(nil, 'public-read', 'Content-type' => 'image/png')
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
      
      context "and remove" do
        setup do
          @s3_mock     = stub
          @bucket_mock = stub
          RightAws::S3.expects(:new).with("12345", "54321", {}).returns(@s3_mock)
          @s3_mock.expects(:bucket).with("testing", true, "public-read").returns(@bucket_mock)
          @key_mock = stub
          @bucket_mock.expects(:key).at_least(2).returns(@key_mock)
          @key_mock.expects(:delete)
          @dummy.destroy_attached_files
        end

        should "succeed" do
          assert true
        end
      end
    end
  end
  
  context "An attachment with S3 storage and bucket defined as a Proc" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => lambda { |attachment| "bucket_#{attachment.instance.other}" },
                    :s3_credentials => {:not => :important}
    end
    
    should "get the right bucket name" do
      assert "bucket_a", Dummy.new(:other => 'a').avatar.bucket_name
      assert "bucket_b", Dummy.new(:other => 'b').avatar.bucket_name
    end
  end

  context "An attachment with S3 storage and specific s3 headers set" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :path => ":attachment/:style/:basename.:extension",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    },
                    :s3_headers => {'Cache-Control' => 'max-age=31557600'}
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown { @file.close }

      context "and saved" do
        setup do
          @s3_mock     = stub
          @bucket_mock = stub
          RightAws::S3.expects(:new).with("12345", "54321", {}).returns(@s3_mock)
          @s3_mock.expects(:bucket).with("testing", true, "public-read").returns(@bucket_mock)
          @key_mock = stub
          @bucket_mock.expects(:key).returns(@key_mock)
          @key_mock.expects(:data=)
          @key_mock.expects(:put).with(nil,
                                       'public-read',
                                       'Content-type' => 'image/png',
                                       'Cache-Control' => 'max-age=31557600')
          @dummy.save
        end

        should "succeed" do
          assert true
        end
      end
    end
  end

  unless ENV["S3_TEST_BUCKET"].blank?
    context "Using S3 for real, an attachment with S3 storage" do
      setup do
        rebuild_model :styles => { :thumb => "100x100", :square => "32x32#" },
                      :storage => :s3,
                      :bucket => ENV["S3_TEST_BUCKET"],
                      :path => ":class/:attachment/:id/:style.:extension",
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "s3.yml"))

        Dummy.delete_all
        @dummy = Dummy.new
      end

      should "be extended by the S3 module" do
        assert Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
      end

      context "when assigned" do
        setup do
          @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
          @dummy.avatar = @file
        end

        teardown { @file.close }

        should "still return a Tempfile when sent #to_io" do
          assert_equal Tempfile, @dummy.avatar.to_io.class
        end

        context "and saved" do
          setup do
            @dummy.save
          end

          should "be on S3" do
            assert true
          end
        end
      end
    end
  end
end
