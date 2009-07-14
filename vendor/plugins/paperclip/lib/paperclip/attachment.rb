module Paperclip
  # The Attachment class manages the files for a given attachment. It saves
  # when the model saves, deletes when the model is destroyed, and processes
  # the file upon assignment.
  class Attachment
    
    def self.default_options
      @default_options ||= {
        :url           => "/system/:attachment/:id/:style/:filename",
        :path          => ":rails_root/public:url",
        :styles        => {},
        :default_url   => "/:attachment/:style/missing.png",
        :default_style => :original,
        :validations   => [],
        :storage       => :filesystem,
        :whiny         => Paperclip.options[:whiny] || Paperclip.options[:whiny_thumbnails]
      }
    end

    attr_reader :name, :instance, :styles, :default_style, :convert_options, :queued_for_write, :options

    # Creates an Attachment object. +name+ is the name of the attachment,
    # +instance+ is the ActiveRecord object instance it's attached to, and
    # +options+ is the same as the hash passed to +has_attached_file+.
    def initialize name, instance, options = {}
      @name              = name
      @instance          = instance

      options = self.class.default_options.merge(options)

      @url               = options[:url]
      @url               = @url.call(self) if @url.is_a?(Proc)
      @path              = options[:path]
      @path              = @path.call(self) if @path.is_a?(Proc)
      @styles            = options[:styles]
      @styles            = @styles.call(self) if @styles.is_a?(Proc)
      @default_url       = options[:default_url]
      @validations       = options[:validations]
      @default_style     = options[:default_style]
      @storage           = options[:storage]
      @whiny             = options[:whiny_thumbnails] || options[:whiny]
      @convert_options   = options[:convert_options] || {}
      @processors        = options[:processors] || [:thumbnail]
      @options           = options
      @queued_for_delete = []
      @queued_for_write  = {}
      @errors            = {}
      @validation_errors = nil
      @dirty             = false

      normalize_style_definition
      initialize_storage
    end

    # What gets called when you call instance.attachment = File. It clears
    # errors, assigns attributes, processes the file, and runs validations. It
    # also queues up the previous file for deletion, to be flushed away on
    # #save of its host.  In addition to form uploads, you can also assign
    # another Paperclip attachment: 
    #   new_user.avatar = old_user.avatar
    # If the file that is assigned is not valid, the processing (i.e.
    # thumbnailing, etc) will NOT be run.
    def assign uploaded_file
      ensure_required_accessors!

      if uploaded_file.is_a?(Paperclip::Attachment)
        uploaded_file = uploaded_file.to_file(:original)
        close_uploaded_file = uploaded_file.respond_to?(:close)
      end

      return nil unless valid_assignment?(uploaded_file)

      uploaded_file.binmode if uploaded_file.respond_to? :binmode
      self.clear

      return nil if uploaded_file.nil?

      @queued_for_write[:original]   = uploaded_file.to_tempfile
      instance_write(:file_name,       uploaded_file.original_filename.strip.gsub(/[^\w\d\.\-]+/, '_'))
      instance_write(:content_type,    uploaded_file.content_type.to_s.strip)
      instance_write(:file_size,       uploaded_file.size.to_i)
      instance_write(:updated_at,      Time.now)

      @dirty = true

      post_process if valid?
 
      # Reset the file size if the original file was reprocessed.
      instance_write(:file_size, @queued_for_write[:original].size.to_i)
    ensure
      uploaded_file.close if close_uploaded_file
      validate
    end

    # Returns the public URL of the attachment, with a given style. Note that
    # this does not necessarily need to point to a file that your web server
    # can access and can point to an action in your app, if you need fine
    # grained security.  This is not recommended if you don't need the
    # security, however, for performance reasons.  set
    # include_updated_timestamp to false if you want to stop the attachment
    # update time appended to the url
    def url style = default_style, include_updated_timestamp = true
      url = original_filename.nil? ? interpolate(@default_url, style) : interpolate(@url, style)
      include_updated_timestamp && updated_at ? [url, updated_at].compact.join(url.include?("?") ? "&" : "?") : url
    end

    # Returns the path of the attachment as defined by the :path option. If the
    # file is stored in the filesystem the path refers to the path of the file
    # on disk. If the file is stored in S3, the path is the "key" part of the
    # URL, and the :bucket option refers to the S3 bucket.
    def path style = default_style
      original_filename.nil? ? nil : interpolate(@path, style)
    end

    # Alias to +url+
    def to_s style = nil
      url(style)
    end

    # Returns true if there are no errors on this attachment.
    def valid?
      validate
      errors.empty?
    end

    # Returns an array containing the errors on this attachment.
    def errors
      @errors
    end

    # Returns true if there are changes that need to be saved.
    def dirty?
      @dirty
    end

    # Saves the file, if there are no errors. If there are, it flushes them to
    # the instance's errors and returns false, cancelling the save.
    def save
      if valid?
        flush_deletes
        flush_writes
        @dirty = false
        true
      else
        flush_errors
        false
      end
    end

    # Clears out the attachment. Has the same effect as previously assigning
    # nil to the attachment. Does NOT save. If you wish to clear AND save,
    # use #destroy.
    def clear
      queue_existing_for_delete
      @errors            = {}
      @validation_errors = nil
    end

    # Destroys the attachment. Has the same effect as previously assigning
    # nil to the attachment *and saving*. This is permanent. If you wish to
    # wipe out the existing attachment but not save, use #clear.
    def destroy
      clear
      save
    end

    # Returns the name of the file as originally assigned, and lives in the
    # <attachment>_file_name attribute of the model.
    def original_filename
      instance_read(:file_name)
    end

    # Returns the size of the file as originally assigned, and lives in the
    # <attachment>_file_size attribute of the model.
    def size
      instance_read(:file_size) || (@queued_for_write[:original] && @queued_for_write[:original].size)
    end

    # Returns the content_type of the file as originally assigned, and lives
    # in the <attachment>_content_type attribute of the model.
    def content_type
      instance_read(:content_type)
    end
    
    # Returns the last modified time of the file as originally assigned, and 
    # lives in the <attachment>_updated_at attribute of the model.
    def updated_at
      time = instance_read(:updated_at)
      time && time.to_i
    end

    # Paths and URLs can have a number of variables interpolated into them
    # to vary the storage location based on name, id, style, class, etc.
    # This method is a deprecated access into supplying and retrieving these
    # interpolations. Future access should use either Paperclip.interpolates
    # or extend the Paperclip::Interpolations module directly.
    def self.interpolations
      warn('[DEPRECATION] Paperclip::Attachment.interpolations is deprecated ' +
           'and will be removed from future versions. ' +
           'Use Paperclip.interpolates instead')
      Paperclip::Interpolations
    end

    # This method really shouldn't be called that often. It's expected use is
    # in the paperclip:refresh rake task and that's it. It will regenerate all
    # thumbnails forcefully, by reobtaining the original file and going through
    # the post-process again.
    def reprocess!
      new_original = Tempfile.new("paperclip-reprocess")
      new_original.binmode
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
    
    # Returns true if a file has been assigned.
    def file?
      !original_filename.blank?
    end

    # Writes the attachment-specific attribute on the instance. For example,
    # instance_write(:file_name, "me.jpg") will write "me.jpg" to the instance's
    # "avatar_file_name" field (assuming the attachment is called avatar).
    def instance_write(attr, value)
      setter = :"#{name}_#{attr}="
      responds = instance.respond_to?(setter)
      self.instance_variable_set("@_#{setter.to_s.chop}", value)
      instance.send(setter, value) if responds || attr.to_s == "file_name"
    end

    # Reads the attachment-specific attribute on the instance. See instance_write
    # for more details.
    def instance_read(attr)
      getter = :"#{name}_#{attr}"
      responds = instance.respond_to?(getter)
      cached = self.instance_variable_get("@_#{getter}")
      return cached if cached
      instance.send(getter) if responds || attr.to_s == "file_name"
    end

    private

    def ensure_required_accessors! #:nodoc:
      %w(file_name).each do |field|
        unless @instance.respond_to?("#{name}_#{field}") && @instance.respond_to?("#{name}_#{field}=")
          raise PaperclipError.new("#{@instance.class} model missing required attr_accessor for '#{name}_#{field}'")
        end
      end
    end

    def log message #:nodoc:
      Paperclip.log(message)
    end

    def valid_assignment? file #:nodoc:
      file.nil? || (file.respond_to?(:original_filename) && file.respond_to?(:content_type))
    end

    def validate #:nodoc:
      unless @validation_errors
        @validation_errors = @validations.inject({}) do |errors, validation|
          name, options = validation
          errors[name] = send(:"validate_#{name}", options) if allow_validation?(options)
          errors
        end
        @validation_errors.reject!{|k,v| v == nil }
        @errors.merge!(@validation_errors)
      end
      @validation_errors
    end

    def allow_validation? options #:nodoc:
      (options[:if].nil? || check_guard(options[:if])) && (options[:unless].nil? || !check_guard(options[:unless]))
    end

    def check_guard guard #:nodoc:
      if guard.respond_to? :call
        guard.call(instance)
      elsif ! guard.blank?
        instance.send(guard.to_s)
      end
    end

    def validate_size options #:nodoc:
      if file? && !options[:range].include?(size.to_i)
        options[:message].gsub(/:min/, options[:min].to_s).gsub(/:max/, options[:max].to_s)
      end
    end

    def validate_presence options #:nodoc:
      options[:message] unless file?
    end

    def validate_content_type options #:nodoc:
      valid_types = [options[:content_type]].flatten
      unless original_filename.blank?
        unless valid_types.blank?
          content_type = instance_read(:content_type)
          unless valid_types.any?{|t| content_type.nil? || t === content_type }
            options[:message] || "is not one of the allowed file types."
          end
        end
      end
    end

    def normalize_style_definition #:nodoc:
      @styles.each do |name, args|
        unless args.is_a? Hash
          dimensions, format = [args, nil].flatten[0..1]
          format             = nil if format.blank?
          @styles[name]      = {
            :processors      => @processors,
            :geometry        => dimensions,
            :format          => format,
            :whiny           => @whiny,
            :convert_options => extra_options_for(name)
          }
        else
          @styles[name] = {
            :processors => @processors,
            :whiny => @whiny,
            :convert_options => extra_options_for(name)
          }.merge(@styles[name])
        end
      end
    end

    def solidify_style_definitions #:nodoc:
      @styles.each do |name, args|
        @styles[name][:geometry] = @styles[name][:geometry].call(instance) if @styles[name][:geometry].respond_to?(:call)
        @styles[name][:processors] = @styles[name][:processors].call(instance) if @styles[name][:processors].respond_to?(:call)
      end
    end

    def initialize_storage #:nodoc:
      @storage_module = Paperclip::Storage.const_get(@storage.to_s.capitalize)
      self.extend(@storage_module)
    end

    def extra_options_for(style) #:nodoc:
      all_options   = convert_options[:all]
      all_options   = all_options.call(instance)   if all_options.respond_to?(:call)
      style_options = convert_options[style]
      style_options = style_options.call(instance) if style_options.respond_to?(:call)

      [ style_options, all_options ].compact.join(" ")
    end

    def post_process #:nodoc:
      return if @queued_for_write[:original].nil?
      solidify_style_definitions
      return if fire_events(:before)
      post_process_styles
      return if fire_events(:after)
    end

    def fire_events(which) #:nodoc:
      return true if callback(:"#{which}_post_process") == false
      return true if callback(:"#{which}_#{name}_post_process") == false
    end

    def callback which #:nodoc:
      instance.run_callbacks(which, @queued_for_write){|result, obj| result == false }
    end

    def post_process_styles #:nodoc:
      @styles.each do |name, args|
        begin
          raise RuntimeError.new("Style #{name} has no processors defined.") if args[:processors].blank?
          @queued_for_write[name] = args[:processors].inject(@queued_for_write[:original]) do |file, processor|
            Paperclip.processor(processor).make(file, args, self)
          end
        rescue PaperclipError => e
          log("An error was received while processing: #{e.inspect}")
          (@errors[:processing] ||= []) << e.message if @whiny
        end
      end
    end

    def interpolate pattern, style = default_style #:nodoc:
      Paperclip::Interpolations.interpolate(pattern, self, style)
    end

    def queue_existing_for_delete #:nodoc:
      return unless file?
      @queued_for_delete += [:original, *@styles.keys].uniq.map do |style|
        path(style) if exists?(style)
      end.compact
      instance_write(:file_name, nil)
      instance_write(:content_type, nil)
      instance_write(:file_size, nil)
      instance_write(:updated_at, nil)
    end

    def flush_errors #:nodoc:
      @errors.each do |error, message|
        [message].flatten.each {|m| instance.errors.add(name, m) }
      end
    end

  end
end

