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

=end
        def make_permalink(options={})
          options[:field] ||= "permalink"
          options[:param] = options.delete(:with)
          options[:escape] ||= true
          options[:prepend_id] ||= false
    
          if self.column_names.include?(options[:field].to_s)
            options[:field_to_encode] = options[:param]
            options[:param] = options[:field]
      
            before_validation :save_permalink
            validates_uniqueness_of options[:param]
            validates_presence_of options[:param]
          end
    
          self.permalink_options = options
  	      extend Railslove::Plugins::FindByParam::SingletonMethods
        	include Railslove::Plugins::FindByParam::InstanceMethods
    	  rescue
    	    puts "Database not available"
        end
      end
      
      module SingletonMethods
  
        # found somewhere on the web.... don't know where... but it's from a clever guy - (done some motifications)
        def escape(str)
          return "" if str.blank? # hack if the str/attribute is nil/blank
          s = Iconv.iconv('ascii//ignore//translit', 'utf-8', str.dup).to_s
          returning str.dup.to_s do |s|
            s.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
            s.gsub!(/[^\w^-]+/, '') # kill non-word chars except -
            s.strip!            # ohh la la
            s.downcase!         # :D
            s.gsub!(/([^ a-zA-Z0-9_-]+)/n,"") # and now kill every char not allowed.
          end
        end
        
=begin rdoc

Search for an object by the defined permalink column. Similar to find_by_login.
Returns nil if nothing is found
Accepts an options hash as a second parameter which is passed on to the rails finder.
=end
        def find_by_param(value,args={})
          param = permalink_options[:prepend_id] ? "id" : permalink_options[:param]
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
        
        private
        
        def save_permalink
          return unless self.class.column_names.include?(permalink_options[:field].to_s)
          counter = 0
          base_value = escape_and_truncate_for_permalink(read_attribute(permalink_options[:field_to_encode]))
          permalink_value = "#{base_value}"
          
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
        
        def escape(value)
          self.class.escape(value)
        end
        
        #this escapes and truncates a value. default length is 100
        #used to escape and truncate permalink value
        def escape_and_truncate_for_permalink(value, length=100)
          self.class.escape(value)[0..length]
        end
      end
      
    end
  end
end