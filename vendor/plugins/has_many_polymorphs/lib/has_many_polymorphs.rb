
require 'active_record'

RAILS_DEFAULT_LOGGER = nil unless defined? RAILS_DEFAULT_LOGGER

require 'has_many_polymorphs/reflection'
require 'has_many_polymorphs/association'
require 'has_many_polymorphs/class_methods'

require 'has_many_polymorphs/support_methods'
require 'has_many_polymorphs/base'

class ActiveRecord::Base
  extend ActiveRecord::Associations::PolymorphicClassMethods 
end

if ENV['HMP_DEBUG'] || ENV['RAILS_ENV'] =~ /development|test/ && ENV['USER'] == 'eweaver'
  require 'has_many_polymorphs/debugging_tools' 
end

if defined? Rails and RAILS_ENV and RAILS_ROOT
  _logger_warn "rails environment detected"
  require 'has_many_polymorphs/configuration'
  require 'has_many_polymorphs/autoload'
end

_logger_debug "loaded ok"
