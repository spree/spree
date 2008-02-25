require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'net/http'

class S3Test < Test::Unit::TestCase
  if File.exist?(File.join(File.dirname(__FILE__), '../../amazon_s3.yml'))
    include BaseAttachmentTests
    attachment_model S3Attachment

    def test_should_create_correct_bucket_name(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal attachment.s3_config[:bucket_name], attachment.bucket_name
    end

    test_against_subclass :test_should_create_correct_bucket_name, S3Attachment

    def test_should_create_default_path_prefix(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal File.join(attachment_model.table_name, attachment.attachment_path_id), attachment.base_path
    end

    test_against_subclass :test_should_create_default_path_prefix, S3Attachment

    def test_should_create_custom_path_prefix(klass = S3WithPathPrefixAttachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal File.join('some/custom/path/prefix', attachment.attachment_path_id), attachment.base_path
    end

    test_against_subclass :test_should_create_custom_path_prefix, S3WithPathPrefixAttachment

    def test_should_create_valid_url(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal "#{s3_protocol}#{s3_hostname}#{s3_port_string}/#{attachment.bucket_name}/#{attachment.full_filename}", attachment.s3_url
    end

    test_against_subclass :test_should_create_valid_url, S3Attachment

    def test_should_create_authenticated_url(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_match /^http.+AWSAccessKeyId.+Expires.+Signature.+/, attachment.authenticated_s3_url(:use_ssl => true)
    end

    test_against_subclass :test_should_create_authenticated_url, S3Attachment

    def test_should_save_attachment(klass = S3Attachment)
      attachment_model klass
      assert_created do
        attachment = upload_file :filename => '/files/rails.png'
        assert_valid attachment
        assert attachment.image?
        assert !attachment.size.zero?
        assert_kind_of Net::HTTPOK, http_response_for(attachment.s3_url)
      end
    end

    test_against_subclass :test_should_save_attachment, S3Attachment

    def test_should_delete_attachment_from_s3_when_attachment_record_destroyed(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'

      urls = [attachment.s3_url] + attachment.thumbnails.collect(&:s3_url)

      urls.each {|url| assert_kind_of Net::HTTPOK, http_response_for(url) }
      attachment.destroy
      urls.each do |url|
        begin
          http_response_for(url)
        rescue Net::HTTPForbidden, Net::HTTPNotFound
          nil
        end
      end
    end

    test_against_subclass :test_should_delete_attachment_from_s3_when_attachment_record_destroyed, S3Attachment

    protected
      def http_response_for(url)
        url = URI.parse(url)
        Net::HTTP.start(url.host, url.port) {|http| http.request_head(url.path) }
      end
      
      def s3_protocol
        Technoweenie::AttachmentFu::Backends::S3Backend.protocol
      end
      
      def s3_hostname
        Technoweenie::AttachmentFu::Backends::S3Backend.hostname
      end

      def s3_port_string
        Technoweenie::AttachmentFu::Backends::S3Backend.port_string
      end
  else
    def test_flunk_s3
      puts "s3 config file not loaded, tests not running"
    end
  end
end