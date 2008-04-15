#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################

require 'action_mailer'

# This line seems to be necessary in order to help ActionMailer find the required views
ActionMailer::Base.template_root = "#{SPREE_ROOT}/app/views"

module Spree
  module MailerViewPathsExtension
    def self.included(base)
      base.class_eval do
        cattr_accessor :view_paths
        self.view_paths = [ActionMailer::Base.template_root].compact
        
        alias :create_without_view_paths! :create!
        alias :create! :create_with_view_paths!
        
        alias :initialize_template_class_without_view_paths :initialize_template_class
        alias :initialize_template_class :initialize_template_class_with_view_paths
      end
    end
    
    def full_template_path(template)
      view_paths.each do |path|
        full_path = File.join(path, template)
        return full_path unless Dir["#{full_path}.*"].empty?
      end
      nil
    end
    
    def create_with_view_paths!(method_name, *parameters) #:nodoc:
      initialize_defaults(method_name)
      __send__(method_name, *parameters)
      
      # If an explicit, textual body has not been set, we check assumptions.
      unless String === @body
        # First, we look to see if there are any likely templates that match,
        # which include the content-type in their file name (i.e.,
        # "the_template_file.text.html.erb", etc.). Only do this if parts
        # have not already been specified manually.
        if @parts.empty?
          # Spree: begin modifications
          full_path = full_template_path("#{mailer_name}/#{@template}")
          templates = Dir.glob("#{full_path}.*")
          # Spree: end modifications
          templates.each do |path|
            basename = File.basename(path)
            template_regex = Regexp.new("^([^\\\.]+)\\\.([^\\\.]+\\\.[^\\\.]+)\\\.(" + template_extensions.join('|') + ")$")
            next unless md = template_regex.match(basename)
            template_name = basename
            content_type = md.captures[1].gsub('.', '/')
            # Spree: begin modifications
            @parts << ActionMailer::Part.new(:content_type => content_type,
              :disposition => "inline", :charset => charset,
              :body => render_message(template_name, @body))
            # Spree: end modifications
          end
          unless @parts.empty?
            @content_type = "multipart/alternative"
            @parts = sort_parts(@parts, @implicit_parts_order)
          end
        end
        
        # Then, if there were such templates, we check to see if we ought to
        # also render a "normal" template (without the content type). If a
        # normal template exists (or if there were no implicit parts) we render
        # it.
        template_exists = @parts.empty?
        template_exists ||= Dir.glob("#{template_path}/#{@template}.*").any? { |i| File.basename(i).split(".").length == 2 }
        @body = render_message(@template, @body) if template_exists
        
        # Finally, if there are other message parts and a textual body exists,
        # we shift it onto the front of the parts and set the body to nil (so
        # that create_mail doesn't try to render it in addition to the parts).
        if !@parts.empty? && String === @body
          # Spree: begin modifications
          @parts.unshift ActionMailer::Part.new(:charset => charset, :body => @body)
          # Spree: end modifications
          @body = nil
        end
      end
      
      # If this is a multipart e-mail add the mime_version if it is not
      # already set.
      @mime_version ||= "1.0" if !@parts.empty?
      
      # build the mail object itself
      @mail = create_mail
    end
    
    def initialize_template_class_with_view_paths(assigns)
      full_path = File.dirname(File.dirname(full_template_path("#{mailer_name}/#{@template}")))
      ActionView::Base.new([full_path], assigns, self)
    end
  end
end

ActionMailer::Base.send(:include, Spree::MailerViewPathsExtension)