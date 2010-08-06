# This is a modified version of the original find_by_param plugin by Michael Bumann.  Simplified to use Rails 2.2
# functionality and tossed out some features not worth supporting.

# ++
# Copyright (c) 2007 [Michael Bumann - Railslove.com]
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# --

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
            before_validation(:on => :create){ save_permalink }
          end

          self.permalink_options = options
          extend Railslove::Plugins::FindByParam::SingletonMethods
          include Railslove::Plugins::FindByParam::InstanceMethods
        rescue
          # Database is not available (not a problem if we're running rake db:create or rake db:bootstrap)
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
          return if !changed?

          base_value = to_param
          permalink_value = base_value
          query = self.class.send("where", "#{permalink_options[:field]} = ?", permalink_value)
          counter = 0
          unless query.limit(1).empty?
            permalink_value = "#{base_value}-#{counter += 1}"
            query = self.class.send("where", "#{permalink_options[:field]} = ?", permalink_value)
          end
          write_attribute(permalink_options[:field], permalink_value)
          true

        end
      end

    end
  end
end

class ActiveRecord::Base
  class_inheritable_accessor :permalink_options
  self.permalink_options = {:param => :id}

  #default finders these are overwritten if you use make_permalink in your model
  def self.find_by_param(value,args={})
    find_by_id(value,args)
  end
  def self.find_by_param!(value,args={})
    find(value,args)
  end

end
ActiveRecord::Base.send(:include, Railslove::Plugins::FindByParam)