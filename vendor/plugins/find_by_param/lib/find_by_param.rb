begin
  require "active_support/multibyte"
rescue LoadError
  require "rubygems"
  require "active_support/multibyte"
end
module Railslove
  module Plugins
    module FindByParam
      
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        
        
=begin rdoc

This method initializes find_by_param

  class Post < ActiveRecord::Base
    make_permalink :with => :title, :prepend_id=>true
  end

The only required parameter, is <tt>:with</tt>. 

If you want to use a non URL-save attribute as permalink your model should have a permalink-column to save the escaped permalink value. This field is then used for search.

If your you can just say make_permalink :with => :login and you're done. 

You can use for example User.find_by_param(params[:id], args) to find the user by the defined permalink. 

== Available options

<tt>:with</tt>:: (required) The attribute that should be used as permalink
<tt>:field</tt>:: The name of your permalink column. make_permalink first checks if there is a column. 
<tt>:prepend_id</tt>:: [true|false] Do you want to prepend the ID to the permalink? for URLs like: posts/123-my-post-title - find_by_param uses the ID column to search.
<tt>:escape</tt>:: [true|false] Do you want to escape the permalink value? (strip chars like öä?&?) - actually you must do that
<tt>:validate</tt>:: [true|false] Don't validate the :with field - set this to false if you validate it on your own
=end
        def make_permalink(options={})
          options[:field] ||= "permalink"
          options[:param] = options[:with] # :with => :login - but if we have a spcific permalink column we need to set :param to the name of that column
          options[:escape] ||= true
          options[:prepend_id] ||= false
          options[:param_size] ||= 50
          options[:validate] ||= true
          
          # validate if there is something we can use as param. you can overwrite the validate_param_is_not_blank method to customize the validation and the error messge.
          if !options[:prepend_id] || !options[:validate]
            validate :validate_param_is_not_blank
          end
          
          if self.column_names.include?(options[:field].to_s)
            options[:param] = options[:field]
            before_save :save_permalink
          end
    
          self.permalink_options = options
  	      extend Railslove::Plugins::FindByParam::SingletonMethods
        	include Railslove::Plugins::FindByParam::InstanceMethods
    	  rescue
    	    puts "[find_by_param error] database not available?"
        end
      end
      
      module SingletonMethods
  
        # borrowed from http://github.com/henrik/slugalizer ;) thanks henrik http://github.com/henrik
        def escape(str, separator='-')
          return "" if str.blank? # hack if the str/attribute is nil/blank
          re_separator = Regexp.escape(separator)
          result = ActiveSupport::Multibyte::Handlers::UTF8Handler.normalize(str.to_s, :kd)
          result.gsub!(/[^\x00-\x7F]+/, '') # Remove non-ASCII (e.g. diacritics).
          result.gsub!(/[^a-z0-9\-_\+]+/i, separator) # Turn non-slug chars into the separator.
          result.gsub!(/#{re_separator}{2,}/, separator) # No more than one of the separator in a row.
          result.gsub!(/^#{re_separator}|#{re_separator}$/, '') # Remove leading/trailing separator.
          result.downcase!
          result
        end
          
=begin rdoc

Search for an object by the defined permalink column. Similar to find_by_login.
Returns nil if nothing is found
Accepts an options hash as a second parameter which is passed on to the rails finder.
=end
        def find_by_param(value,args={})
          if permalink_options[:prepend_id]
            param = "id"
            value = value.to_i
          else
            param = permalink_options[:param]
          end
          self.send("find_by_#{param}".to_sym, value, args)
        end

=begin rdoc

Like find_by_param but raises an ActiveRecord::RecordNotFound error if nothing is found. Similar to find() 

Accepts an options hash as a second parameter which is passed on to the rails finder.
=end
        def find_by_param!(value, args={})
          param = permalink_options[:param]
          obj = find_by_param(value, args)
          raise ::ActiveRecord::RecordNotFound unless obj
          obj
        end
      end
      
      module InstanceMethods
        def to_param
          value = self.send(permalink_options[:param]).dup.to_s.downcase rescue ""
          returning "" do |param|
            param << "#{id}" if value.blank? || permalink_options[:prepend_id]
            param << "-" if permalink_options[:prepend_id]
            param << "#{escape_and_truncate_for_permalink(value)}"
          end
        end
        
        protected
        
        def save_permalink
          return unless self.class.column_names.include?(permalink_options[:field].to_s)
          counter = 0
          base_value = escape_and_truncate_for_permalink(read_attribute(permalink_options[:with]))
          permalink_value = "#{base_value}".downcase
          
          conditions = ["#{self.class.table_name}.#{permalink_options[:field]} = ?", permalink_value]
          unless new_record?
            conditions.first << " and #{self.class.table_name}.#{self.class.primary_key} != ?"
            conditions       << self.send(self.class.primary_key.to_sym)
          end
          while self.class.count(:all, :conditions => conditions) > 0
            permalink_value = "#{base_value}-#{counter += 1}"
            conditions[1] = permalink_value
          end
          write_attribute(permalink_options[:field], permalink_value)
          true
        end
        
        def validate_param_is_not_blank
          errors.add(permalink_options[:with], "must have at least one non special character (a-z 0-9)") if self.escape( self.send(permalink_options[:with]) ).blank?
        end
        
        def escape(value)
          "#{value.respond_to?("parameterize") ? value.parameterize : self.class.escape(value)}"
        end
        
        #this escapes and truncates a value.
        #used to escape and truncate permalink value
        def escape_and_truncate_for_permalink(value)
          self.escape(value)[0...self.permalink_options[:param_size]]
        end
      end
      
    end
  end
end