module Paperclip
  module Storage

    # The default place to store attachments is in the filesystem. Files on the local
    # filesystem can be very easily served by Apache without requiring a hit to your app.
    # They also can be processed more easily after they've been saved, as they're just
    # normal files. There is one Filesystem-specific option for has_attached_file.
    # * +path+: The location of the repository of attachments on disk. This can (and, in
    #   almost all cases, should) be coordinated with the value of the +url+ option to
    #   allow files to be saved into a place where Apache can serve them without
    #   hitting your app. Defaults to 
    #   ":rails_root/public/:attachment/:id/:style/:basename.:extension"
    #   By default this places the files in the app's public directory which can be served 
    #   directly. If you are using capistrano for deployment, a good idea would be to 
    #   make a symlink to the capistrano-created system directory from inside your app's 
    #   public directory.
    #   See Paperclip::Attachment#interpolate for more information on variable interpolaton.
    #     :path => "/var/app/attachments/:class/:id/:style/:filename"
    module Filesystem
      def self.extended base
      end
      
      def exists?(style = default_style)
        if original_filename
          File.exist?(path(style))
        else
          false
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        @queued_for_write[style] || (File.new(path(style)) if exists?(style))
      end
      alias_method :to_io, :to_file

      def flush_writes #:nodoc:
        logger.info("[paperclip] Writing files for #{name}")
        @queued_for_write.each do |style, file|
          FileUtils.mkdir_p(File.dirname(path(style)))
          logger.info("[paperclip] -> #{path(style)}")
          result = file.stream_to(path(style))
          file.close
          result.close
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        logger.info("[paperclip] Deleting files for #{name}")
        @queued_for_delete.each do |path|
          begin
            logger.info("[paperclip] -> #{path}")
            FileUtils.rm(path) if File.exist?(path)
          rescue Errno::ENOENT => e
            # ignore file-not-found, let everything else pass
          end
        end
        @queued_for_delete = []
      end
    end

    # Amazon's S3 file hosting service is a scalable, easy place to store files for
    # distribution. You can find out more about it at http://aws.amazon.com/s3
    # There are a few S3-specific options for has_attached_file:
    # * +s3_credentials+: Takes a path, a File, or a Hash. The path (or File) must point
    #   to a YAML file containing the +access_key_id+ and +secret_access_key+ that Amazon
    #   gives you. You can 'environment-space' this just like you do to your
    #   database.yml file, so different environments can use different accounts:
    #     development:
    #       access_key_id: 123...
    #       secret_access_key: 123... 
    #     test:
    #       access_key_id: abc...
    #       secret_access_key: abc... 
    #     production:
    #       access_key_id: 456...
    #       secret_access_key: 456... 
    #   This is not required, however, and the file may simply look like this:
    #     access_key_id: 456...
    #     secret_access_key: 456... 
    #   In which case, those access keys will be used in all environments. You can also
    #   put your bucket name in this file, instead of adding it to the code directly.
    #   This is useful when you want the same account but a different bucket for 
    #   development versus production.
    # * +s3_permissions+: This is a String that should be one of the "canned" access
    #   policies that S3 provides (more information can be found here:
    #   http://docs.amazonwebservices.com/AmazonS3/2006-03-01/RESTAccessPolicy.html#RESTCannedAccessPolicies)
    #   The default for Paperclip is "public-read".
    # * +s3_protocol+: The protocol for the URLs generated to your S3 assets. Can be either 
    #   'http' or 'https'. Defaults to 'http' when your :s3_permissions are 'public-read' (the
    #   default), and 'https' when your :s3_permissions are anything else.
    # * +bucket+: This is the name of the S3 bucket that will store your files. Remember
    #   that the bucket must be unique across all of Amazon S3. If the bucket does not exist
    #   Paperclip will attempt to create it. The bucket name will not be interpolated.
    # * +url+: There are two options for the S3 url. You can choose to have the bucket's name
    #   placed domain-style (bucket.s3.amazonaws.com) or path-style (s3.amazonaws.com/bucket).
    #   Normally, this won't matter in the slightest and you can leave the default (which is
    #   path-style, or :s3_path_url). But in some cases paths don't work and you need to use
    #   the domain-style (:s3_domain_url). Anything else here will be treated like path-style.
    # * +path+: This is the key under the bucket in which the file will be stored. The
    #   URL will be constructed from the bucket and the path. This is what you will want
    #   to interpolate. Keys should be unique, like filenames, and despite the fact that
    #   S3 (strictly speaking) does not support directories, you can still use a / to
    #   separate parts of your file name.
    module S3
      def self.extended base
        require 'right_aws'
        base.instance_eval do
          @s3_credentials = parse_credentials(@options[:s3_credentials])
          @bucket         = @options[:bucket] || @s3_credentials[:bucket]
          @s3_options     = @options[:s3_options] || {}
          @s3_permissions = @options[:s3_permissions] || 'public-read'
          @s3_protocol    = @options[:s3_protocol] || (@s3_permissions == 'public-read' ? 'http' : 'https')
          @url            = ":s3_path_url" unless @url.to_s.match(/^:s3.*url$/)
        end
        base.class.interpolations[:s3_path_url] = lambda do |attachment, style|
          "#{attachment.s3_protocol}://s3.amazonaws.com/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
        base.class.interpolations[:s3_domain_url] = lambda do |attachment, style|
          "#{attachment.s3_protocol}://#{attachment.bucket_name}.s3.amazonaws.com/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
        ActiveRecord::Base.logger.info("[paperclip] S3 Storage Initalized.")
      end

      def s3
        @s3 ||= RightAws::S3.new(@s3_credentials[:access_key_id],
                                 @s3_credentials[:secret_access_key],
                                 @s3_options)
      end

      def s3_bucket
        @s3_bucket ||= s3.bucket(@bucket, true, @s3_permissions)
      end

      def bucket_name
        @bucket
      end

      def parse_credentials creds
        creds = find_credentials(creds).stringify_keys
        (creds[ENV['RAILS_ENV']] || creds).symbolize_keys
      end
      
      def exists?(style = default_style)
        s3_bucket.key(path(style)) ? true : false
      end

      def s3_protocol
        @s3_protocol
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        @queued_for_write[style] || s3_bucket.key(path(style))
      end
      alias_method :to_io, :to_file

      def flush_writes #:nodoc:
        logger.info("[paperclip] Writing files for #{name}")
        @queued_for_write.each do |style, file|
          begin
            logger.info("[paperclip] -> #{path(style)}")
            key = s3_bucket.key(path(style))
            key.data = file
            key.put(nil, @s3_permissions)
          rescue RightAws::AwsError => e
            raise
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        logger.info("[paperclip] Writing files for #{name}")
        @queued_for_delete.each do |path|
          begin
            logger.info("[paperclip] -> #{path}")
            if file = s3_bucket.key(path)
              file.delete
            end
          rescue RightAws::AwsError
            # Ignore this.
          end
        end
        @queued_for_delete = []
      end
      
      def find_credentials creds
        case creds
        when File:
          YAML.load_file(creds.path)
        when String:
          YAML.load_file(creds)
        when Hash:
          creds
        else
          raise ArgumentError, "Credentials are not a path, file, or hash."
        end
      end
      private :find_credentials

    end
  end
end
