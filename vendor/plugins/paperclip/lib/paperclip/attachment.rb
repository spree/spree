module Paperclip
  # The Attachment class manages the files for a given attachment. It saves when the model saves,
  # deletes when the model is destroyed, and processes the file upon assignment.
  class Attachment
    
    def self.default_options
      @default_options ||= {
        :url           => "/:attachment/:id/:style/:basename.:extension",
        :path          => ":rails_root/public/:attachment/:id/:style/:basename.:extension",
        :styles        => {},
        :default_url   => "/:attachment/:style/missing.png",
        :default_style => :original,
        :validations   => [],
        :storage       => :filesystem
      }
    end

    attr_reader :name, :instance, :styles, :default_style, :convert_options

    # Creates an Attachment object. +name+ is the name of the attachment, +instance+ is the
    # ActiveRecord object instance it's attached to, and +options+ is the same as the hash
    # passed to +has_attached_file+.
    def initialize name, instance, options = {}
      @name              = name
      @instance          = instance

      options = self.class.default_options.merge(options)

      @url               = options[:url]
      @path              = options[:path]
      @styles            = options[:styles]
      @default_url       = options[:default_url]
      @validations       = options[:validations]
      @default_style     = options[:default_style]
      @storage           = options[:storage]
      @whiny_thumbnails  = options[:whiny_thumbnails]
      @convert_options   = options[:convert_options] || {}
      @options           = options
      @queued_for_delete = []
      @queued_for_write  = {}
      @errors            = []
      @validation_errors = nil
      @dirty             = false

      normalize_style_definition
      initialize_storage

      logger.info("[paperclip] Paperclip attachment #{name} on #{instance.class} initialized.")
    end

    # What gets called when you call instance.attachment = File. It clears errors,
    # assigns attributes, processes the file, and runs validations. It also queues up
    # the previous file for deletion, to be flushed away on #save of its host.
    # In addition to form uploads, you can also assign another Paperclip attachment:
    #   new_user.avatar = old_user.avatar
    def assign uploaded_file
      %w(file_name).each do |field|
        unless @instance.class.column_names.include?("#{name}_#{field}")
          raise PaperclipError.new("#{self} model does not have required column '#{name}_#{field}'")
        end
      end

      if uploaded_file.is_a?(Paperclip::Attachment)
        uploaded_file = uploaded_file.to_file(:original)
      end

      return nil unless valid_assignment?(uploaded_file)
      logger.info("[paperclip] Assigning #{uploaded_file.inspect} to #{name}")

      queue_existing_for_delete
      @errors            = []
      @validation_errors = nil

      return nil if uploaded_file.nil?

      logger.info("[paperclip] Writing attributes for #{name}")
      @queued_for_write[:original]        = uploaded_file.to_tempfile
      @instance[:"#{@name}_file_name"]    = uploaded_file.original_filename.strip.gsub /[^\w\d\.\-]+/, '_'
      @instance[:"#{@name}_content_type"] = uploaded_file.content_type.strip
      @instance[:"#{@name}_file_size"]    = uploaded_file.size.to_i
      @instance[:"#{@name}_updated_at"]   = Time.now

      @dirty = true

      post_process
 
      # Reset the file size if the original file was reprocessed.
      @instance[:"#{@name}_file_size"]    = uploaded_file.size.to_i
    ensure
      validate
    end

    # Returns the public URL of the attachment, with a given style. Note that this
    # does not necessarily need to point to a file that your web server can access
    # and can point to an action in your app, if you need fine grained security.
    # This is not recommended if you don't need the security, however, for
    # performance reasons.
    def url style = default_style
      url = original_filename.nil? ? interpolate(@default_url, style) : interpolate(@url, style)
      updated_at ? [url, updated_at].compact.join(url.include?("?") ? "&" : "?") : url
    end

    # Returns the path of the attachment as defined by the :path option. If the
    # file is stored in the filesystem the path refers to the path of the file on
    # disk. If the file is stored in S3, the path is the "key" part of the URL,
    # and the :bucket option refers to the S3 bucket.
    def path style = nil #:nodoc:
      interpolate(@path, style)
    end

    # Alias to +url+
    def to_s style = nil
      url(style)
    end

    # Returns true if there are no errors on this attachment.
    def valid?
      validate
      errors.length == 0
    end

    # Returns an array containing the errors on this attachment.
    def errors
      @errors.compact.uniq
    end

    # Returns true if there are changes that need to be saved.
    def dirty?
      @dirty
    end

    # Saves the file, if there are no errors. If there are, it flushes them to
    # the instance's errors and returns false, cancelling the save.
    def save
      if valid?
        logger.info("[paperclip] Saving files for #{name}")
        flush_deletes
        flush_writes
        @dirty = false
        true
      else
        logger.info("[paperclip] Errors on #{name}. Not saving.")
        flush_errors
        false
      end
    end

    # Returns the name of the file as originally assigned, and as lives in the
    # <attachment>_file_name attribute of the model.
    def original_filename
      instance[:"#{name}_file_name"]
    end
    
    def updated_at
      time = instance[:"#{name}_updated_at"]
      time && time.to_i
    end

    # A hash of procs that are run during the interpolation of a path or url.
    # A variable of the format :name will be replaced with the return value of
    # the proc named ":name". Each lambda takes the attachment and the current
    # style as arguments. This hash can be added to with your own proc if
    # necessary.
    def self.interpolations
      @interpolations ||= {
        :rails_root   => lambda{|attachment,style| RAILS_ROOT },
        :rails_env    => lambda{|attachment,style| RAILS_ENV },
        :class        => lambda do |attachment,style|
                           attachment.instance.class.name.underscore.pluralize
                         end,
        :basename     => lambda do |attachment,style|
                           attachment.original_filename.gsub(File.extname(attachment.original_filename), "")
                         end,
        :extension    => lambda do |attachment,style| 
                           ((style = attachment.styles[style]) && style.last) ||
                           File.extname(attachment.original_filename).gsub(/^\.+/, "")
                         end,
        :id           => lambda{|attachment,style| attachment.instance.id },
        :id_partition => lambda do |attachment, style|
                           ("%09d" % attachment.instance.id).scan(/\d{3}/).join("/")
                         end,
        :attachment   => lambda{|attachment,style| attachment.name.to_s.downcase.pluralize },
        :style        => lambda{|attachment,style| style || attachment.default_style },
      }
    end

    # This method really shouldn't be called that often. It's expected use is in the
    # paperclip:refresh rake task and that's it. It will regenerate all thumbnails
    # forcefully, by reobtaining the original file and going through the post-process
    # again.
    def reprocess!
      new_original = Tempfile.new("paperclip-reprocess")
      if old_original = to_file(:original)
        new_original.write( old_original.read )
        new_original.rewind

        @queued_for_write = { :original => new_original }
        post_process

        old_original.close if old_original.respond_to?(:close)

        save
      else
        true
      end
    end
    
    def file?
      !original_filename.blank?
    end

    private

    def logger
      instance.logger
    end

    def valid_assignment? file #:nodoc:
      file.nil? || (file.respond_to?(:original_filename) && file.respond_to?(:content_type))
    end

    def validate #:nodoc:
      unless @validation_errors
        @validation_errors = @validations.collect do |v|
          v.call(self, instance)
        end.flatten.compact.uniq
        @errors += @validation_errors
      end
      @validation_errors
    end

    def normalize_style_definition
      @styles.each do |name, args|
        dimensions, format = [args, nil].flatten[0..1]
        format             = nil if format == ""
        @styles[name]      = [dimensions, format]
      end
    end

    def initialize_storage
      @storage_module = Paperclip::Storage.const_get(@storage.to_s.capitalize)
      self.extend(@storage_module)
    end

    def extra_options_for(style) #:nodoc:
      [ convert_options[style], convert_options[:all] ].compact.join(" ")
    end

    def post_process #:nodoc:
      return if @queued_for_write[:original].nil?
      logger.info("[paperclip] Post-processing #{name}")
      @styles.each do |name, args|
        begin
          dimensions, format = args
          dimensions = dimensions.call(instance) if dimensions.respond_to? :call
          @queued_for_write[name] = Thumbnail.make(@queued_for_write[:original], 
                                                   dimensions,
                                                   format, 
                                                   extra_options_for(name),
                                                   @whiny_thumnails)
        rescue PaperclipError => e
          @errors << e.message if @whiny_thumbnails
        end
      end
    end

    def interpolate pattern, style = default_style #:nodoc:
      interpolations = self.class.interpolations.sort{|a,b| a.first.to_s <=> b.first.to_s }
      interpolations.reverse.inject( pattern.dup ) do |result, interpolation|
        tag, blk = interpolation
        result.gsub(/:#{tag}/) do |match|
          blk.call( self, style )
        end
      end
    end

    def queue_existing_for_delete #:nodoc:
      return unless file?
      logger.info("[paperclip] Queueing the existing files for #{name} for deletion.")
      @queued_for_delete += [:original, *@styles.keys].uniq.map do |style|
        path(style) if exists?(style)
      end.compact
      @instance[:"#{@name}_file_name"]    = nil
      @instance[:"#{@name}_content_type"] = nil
      @instance[:"#{@name}_file_size"]    = nil
      @instance[:"#{@name}_updated_at"]   = nil
    end

    def flush_errors #:nodoc:
      @errors.each do |error|
        instance.errors.add(name, error)
      end
    end

  end
end

