require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'right_aws'

require File.join(File.dirname(__FILE__), '..', 'lib', 'paperclip', 'geometry.rb')

class StorageTest < Test::Unit::TestCase
  context "Parsing S3 credentials" do
    setup do
      rebuild_model :storage => :s3,
                    :bucket => "testing",
                    :s3_credentials => {:not => :important}

      @dummy = Dummy.new
      @avatar = @dummy.avatar

      @current_env = ENV['RAILS_ENV']
    end

    teardown do
      ENV['RAILS_ENV'] = @current_env
    end

    should "get the correct credentials when RAILS_ENV is production" do
      ENV['RAILS_ENV'] = 'production'
      assert_equal({:key => "12345"},
                   @avatar.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "get the correct credentials when RAILS_ENV is development" do
      ENV['RAILS_ENV'] = 'development'
      assert_equal({:key => "54321"},
                   @avatar.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "return the argument if the key does not exist" do
      ENV['RAILS_ENV'] = "not really an env"
      assert_equal({:test => "12345"}, @avatar.parse_credentials(:test => "12345"))
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
    end

    should "get the right bucket in production", :before => lambda{ ENV.expects(:[]).returns('production') } do
      assert_equal "prod_bucket", @dummy.avatar.bucket_name
    end

    should "get the right bucket in development", :before => lambda{ ENV.expects(:[]).returns('development') } do
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
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'))
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

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
          @key_mock.expects(:put)
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
          @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'))
          @dummy.avatar = @file
        end

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
