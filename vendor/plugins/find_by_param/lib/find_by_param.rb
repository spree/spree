# This is a modified version of the original find_by_param plugin by Michael Bumann.  Simplified to use Rails 2.2
# functionality and tossed out some features not worth supporting.
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
                
        def make_permalink(options={})
          options[:field] ||= "permalink"
          
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

        def find_by_param(value,args={})
          if permalink_options[:prepend_id]
            param = "id"
            value = value.to_i
          else
            param = permalink_options[:field]
          end
          self.send("find_by_#{param}".to_sym, value, args)
        end

        def find_by_param!(value, args={})
          param = permalink_options[:field]
          obj = find_by_param(value, args)
          raise ::ActiveRecord::RecordNotFound unless obj
          obj
        end
      end
      
      module InstanceMethods

        protected        
        def save_permalink
          return unless self.class.column_names.include?(permalink_options[:field].to_s)
          counter = 0
          permalink_value = self.to_param
          
          conditions = ["#{self.class.table_name}.#{permalink_options[:field]} = ?", permalink_value]
          unless new_record?
            conditions.first << " and #{self.class.table_name}.#{self.class.primary_key} != ?"
            conditions       << self.send(self.class.primary_key.to_sym)
          end
          while self.class.count(:all, :conditions => conditions) > 0
            permalink_value = "#{permalink_value}-#{counter += 1}"
            conditions[1] = permalink_value
          end
          write_attribute(permalink_options[:field], permalink_value)
          true
        end
      end
      
    end
  end
end