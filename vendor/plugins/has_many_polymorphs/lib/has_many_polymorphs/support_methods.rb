
class String

  # Changes an underscored string into a class reference.
  def _as_class
    # classify expects self to be plural
    self.classify.constantize
  end

  # For compatibility with the Symbol extensions.
  alias :_singularize :singularize
  alias :_pluralize :pluralize
  alias :_classify :classify
end

class Symbol
  
  # Changes an underscored symbol into a class reference.
  def _as_class; self.to_s._as_class; end
  
  # Changes a plural symbol into a singular symbol.
  def _singularize; self.to_s.singularize.to_sym; end

  # Changes a singular symbol into a plural symbol.
  def _pluralize; self.to_s.pluralize.to_sym; end

  # Changes a symbol into a class name string.
  def _classify; self.to_s.classify; end
end

class Array

  # Flattens the first level of self.
  def _flatten_once
    self.inject([]){|r, el| r + Array(el)}
  end

  # Rails 1.2.3 compatibility method. Copied from http://dev.rubyonrails.org/browser/trunk/activesupport/lib/active_support/core_ext/array/extract_options.rb?rev=7217 
  def _extract_options!
    last.is_a?(::Hash) ? pop : {}
  end
end

class Hash

  # An implementation of select that returns a Hash.
  def _select
    if RUBY_VERSION >= "1.9"
      Hash[*self.select {|k, v| yield k, v }.flatten]
    else
      Hash[*self.select do |key, value|
        yield key, value
      end._flatten_once]
    end
  end
end

class Object

  # Returns the metaclass of self.
  def _metaclass; (class << self; self; end); end

  # Logger shortcut.
  def _logger_debug s
    s = "** has_many_polymorphs: #{s}"
    RAILS_DEFAULT_LOGGER.debug(s) if RAILS_DEFAULT_LOGGER
  end  

  # Logger shortcut.  
  def _logger_warn s
    s = "** has_many_polymorphs: #{s}"
    if RAILS_DEFAULT_LOGGER
      RAILS_DEFAULT_LOGGER.warn(s) 
    else
      $stderr.puts(s)
    end    
  end
  
end

class ActiveRecord::Base

  # Return the base class name as a string.
  def _base_class_name
    self.class.base_class.name.to_s
  end
  
end
