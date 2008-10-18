# Paperclip allows file attachments that are stored in the filesystem. All graphical
# transformations are done using the Graphics/ImageMagick command line utilities and
# are stored in Tempfiles until the record is saved. Paperclip does not require a
# separate model for storing the attachment's information, instead adding a few simple
# columns to your table.
#
# Author:: Jon Yurek
# Copyright:: Copyright (c) 2008 thoughtbot, inc.
# License:: MIT License (http://www.opensource.org/licenses/mit-license.php)
#
# Paperclip defines an attachment as any file, though it makes special considerations
# for image files. You can declare that a model has an attached file with the
# +has_attached_file+ method:
#
#   class User < ActiveRecord::Base
#     has_attached_file :avatar, :styles => { :thumb => "100x100" }
#   end
#
#   user = User.new
#   user.avatar = params[:user][:avatar]
#   user.avatar.url
#   # => "/users/avatars/4/original_me.jpg"
#   user.avatar.url(:thumb)
#   # => "/users/avatars/4/thumb_me.jpg"
#
# See the +has_attached_file+ documentation for more details.

require 'tempfile'
require 'paperclip/upfile'
require 'paperclip/iostream'
require 'paperclip/geometry'
require 'paperclip/thumbnail'
require 'paperclip/storage'
require 'paperclip/attachment'

# The base module that gets included in ActiveRecord::Base. See the
# documentation for Paperclip::ClassMethods for more useful information.
module Paperclip

  VERSION = "2.1.2"

  class << self
    # Provides configurability to Paperclip. There are a number of options available, such as:
    # * whiny_thumbnails: Will raise an error if Paperclip cannot process thumbnails of 
    #   an uploaded image. Defaults to true.
    # * image_magick_path: Defines the path at which to find the +convert+ and +identify+ 
    #   programs if they are not visible to Rails the system's search path. Defaults to 
    #   nil, which uses the first executable found in the search path.
    def options
      @options ||= {
        :whiny_thumbnails  => true,
        :image_magick_path => nil
      }
    end

    def path_for_command command #:nodoc:
      path = [options[:image_magick_path], command].compact
      File.join(*path)
    end

    def run cmd, params = "", expected_outcodes = 0
      output = `#{%Q[#{path_for_command(cmd)} #{params} 2>#{bit_bucket}].gsub(/\s+/, " ")}`
      unless [expected_outcodes].flatten.include?($?.exitstatus)
        raise PaperclipCommandLineError, "Error while running #{cmd}"
      end
      output
    end

    def bit_bucket
      File.exists?("/dev/null") ? "/dev/null" : "NUL"
    end

    def included base #:nodoc:
      base.extend ClassMethods
    end
  end

  class PaperclipError < StandardError #:nodoc:
  end

  class PaperclipCommandLineError < StandardError #:nodoc:
  end

  class NotIdentifiedByImageMagickError < PaperclipError #:nodoc:
  end

  module ClassMethods
    # +has_attached_file+ gives the class it is called on an attribute that maps to a file. This
    # is typically a file stored somewhere on the filesystem and has been uploaded by a user. 
    # The attribute returns a Paperclip::Attachment object which handles the management of
    # that file. The intent is to make the attachment as much like a normal attribute. The 
    # thumbnails will be created when the new file is assigned, but they will *not* be saved 
    # until +save+ is called on the record. Likewise, if the attribute is set to +nil+ is 
    # called on it, the attachment will *not* be deleted until +save+ is called. See the 
    # Paperclip::Attachment documentation for more specifics. There are a number of options 
    # you can set to change the behavior of a Paperclip attachment:
    # * +url+: The full URL of where the attachment is publically accessible. This can just
    #   as easily point to a directory served directly through Apache as it can to an action
    #   that can control permissions. You can specify the full domain and path, but usually
    #   just an absolute path is sufficient. The leading slash must be included manually for 
    #   absolute paths. The default value is "/:class/:attachment/:id/:style_:filename". See
    #   Paperclip::Attachment#interpolate for more information on variable interpolaton.
    #     :url => "/:attachment/:id/:style_:basename:extension"
    #     :url => "http://some.other.host/stuff/:class/:id_:extension"
    # * +default_url+: The URL that will be returned if there is no attachment assigned. 
    #   This field is interpolated just as the url is. The default value is 
    #   "/:class/:attachment/missing_:style.png"
    #     has_attached_file :avatar, :default_url => "/images/default_:style_avatar.png"
    #     User.new.avatar_url(:small) # => "/images/default_small_avatar.png"
    # * +styles+: A hash of thumbnail styles and their geometries. You can find more about 
    #   geometry strings at the ImageMagick website 
    #   (http://www.imagemagick.org/script/command-line-options.php#resize). Paperclip
    #   also adds the "#" option (e.g. "50x50#"), which will resize the image to fit maximally 
    #   inside the dimensions and then crop the rest off (weighted at the center). The 
    #   default value is to generate no thumbnails.
    # * +default_style+: The thumbnail style that will be used by default URLs. 
    #   Defaults to +original+.
    #     has_attached_file :avatar, :styles => { :normal => "100x100#" },
    #                       :default_style => :normal
    #     user.avatar.url # => "/avatars/23/normal_me.png"
    # * +whiny_thumbnails+: Will raise an error if Paperclip cannot process thumbnails of an
    #   uploaded image. This will ovrride the global setting for this attachment. 
    #   Defaults to true. 
    # * +convert_options+: When creating thumbnails, use this free-form options
    #   field to pass in various convert command options.  Typical options are "-strip" to
    #   remove all Exif data from the image (save space for thumbnails and avatars) or
    #   "-depth 8" to specify the bit depth of the resulting conversion.  See ImageMagick
    #   convert documentation for more options: (http://www.imagemagick.org/script/convert.php)
    #   Note that this option takes a hash of options, each of which correspond to the style
    #   of thumbnail being generated. You can also specify :all as a key, which will apply
    #   to all of the thumbnails being generated. If you specify options for the :original,
    #   it would be best if you did not specify destructive options, as the intent of keeping
    #   the original around is to regenerate all the thumbnails then requirements change.
    #     has_attached_file :avatar, :styles => { :large => "300x300", :negative => "100x100" }
    #                                :convert_options => {
    #                                  :all => "-strip",
    #                                  :negative => "-negate"
    #                                }
    # * +storage+: Chooses the storage backend where the files will be stored. The current
    #   choices are :filesystem and :s3. The default is :filesystem. Make sure you read the
    #   documentation for Paperclip::Storage::Filesystem and Paperclip::Storage::S3
    #   for backend-specific options.
    def has_attached_file name, options = {}
      include InstanceMethods

      write_inheritable_attribute(:attachment_definitions, {}) if attachment_definitions.nil?
      attachment_definitions[name] = {:validations => []}.merge(options)

      after_save :save_attached_files
      before_destroy :destroy_attached_files

      define_method name do |*args|
        a = attachment_for(name)
        (args.length > 0) ? a.to_s(args.first) : a
      end

      define_method "#{name}=" do |file|
        attachment_for(name).assign(file)
      end

      define_method "#{name}?" do
        attachment_for(name).file?
      end

      validates_each(name) do |record, attr, value|
        value.send(:flush_errors) unless value.valid?
      end
    end

    # Places ActiveRecord-style validations on the size of the file assigned. The
    # possible options are:
    # * +in+: a Range of bytes (i.e. +1..1.megabyte+),
    # * +less_than+: equivalent to :in => 0..options[:less_than]
    # * +greater_than+: equivalent to :in => options[:greater_than]..Infinity
    # * +message+: error message to display, use :min and :max as replacements
    def validates_attachment_size name, options = {}
      attachment_definitions[name][:validations] << lambda do |attachment, instance|
        unless options[:greater_than].nil?
          options[:in] = (options[:greater_than]..(1/0)) # 1/0 => Infinity
        end
        unless options[:less_than].nil?
          options[:in] = (0..options[:less_than])
        end
        
        if attachment.file? && !options[:in].include?(instance[:"#{name}_file_size"].to_i)
          min = options[:in].first
          max = options[:in].last
          
          if options[:message]
            options[:message].gsub(/:min/, min.to_s).gsub(/:max/, max.to_s)
          else
            "file size is not between #{min} and #{max} bytes."
          end
        end
      end
    end

    # Adds errors if thumbnail creation fails. The same as specifying :whiny_thumbnails => true.
    def validates_attachment_thumbnails name, options = {}
      attachment_definitions[name][:whiny_thumbnails] = true
    end

    # Places ActiveRecord-style validations on the presence of a file.
    def validates_attachment_presence name, options = {}
      attachment_definitions[name][:validations] << lambda do |attachment, instance|
        unless attachment.file?
          options[:message] || "must be set."
        end
      end
    end
    
    # Places ActiveRecord-style validations on the content type of the file assigned. The
    # possible options are:
    # * +content_type+: Allowed content types.  Can be a single content type or an array.
    #   Each type can be a String or a Regexp. It should be noted that Internet Explorer uploads
    #   files with content_types that you may not expect. For example, JPEG images are given
    #   image/pjpeg and PNGs are image/x-png, so keep that in mind when determining how you match.
    #   Allows all by default.
    # * +message+: The message to display when the uploaded file has an invalid content type.
    def validates_attachment_content_type name, options = {}
      attachment_definitions[name][:validations] << lambda do |attachment, instance|
        valid_types = [options[:content_type]].flatten
        
        unless attachment.original_filename.blank?
          unless options[:content_type].blank?
            content_type = instance[:"#{name}_content_type"]
            unless valid_types.any?{|t| t === content_type }
              options[:message] || "is not one of the allowed file types."
            end
          end
        end
      end
    end

    # Returns the attachment definitions defined by each call to has_attached_file.
    def attachment_definitions
      read_inheritable_attribute(:attachment_definitions)
    end

  end

  module InstanceMethods #:nodoc:
    def attachment_for name
      @attachments ||= {}
      @attachments[name] ||= Attachment.new(name, self, self.class.attachment_definitions[name])
    end
    
    def each_attachment
      self.class.attachment_definitions.each do |name, definition|
        yield(name, attachment_for(name))
      end
    end

    def save_attached_files
      logger.info("[paperclip] Saving attachments.")
      each_attachment do |name, attachment|
        attachment.send(:save)
      end
    end

    def destroy_attached_files
      logger.info("[paperclip] Deleting attachments.")
      each_attachment do |name, attachment|
        attachment.send(:queue_existing_for_delete)
        attachment.send(:flush_deletes)
      end
    end
  end

end

# Set it all up.
if Object.const_defined?("ActiveRecord")
  ActiveRecord::Base.send(:include, Paperclip)
  File.send(:include, Paperclip::Upfile)
end
