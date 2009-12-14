# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
SPREE_GEM_VERSION = '0.9.99' unless defined? SPREE_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Spree::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use. To use Rails without a database
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Specify gems that this application depends on.
  # They can then be installed with "rake gems:install" on new installations.
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "aws-s3", :lib => "aws/s3"

  config.gem "highline", :version => '>=1.4.0'
  config.gem 'authlogic', :version => '>=2.1.2'
  config.gem 'authlogic-oid', :lib => "authlogic_openid"
  config.gem "activemerchant", :lib => "active_merchant", :version => '>=1.4.2'
  config.gem 'activerecord-tableless', :lib => 'tableless', :version => '>=0.1.0'
  config.gem 'less', :version => '>=1.2.20', :source => "http://gemcutter.org"
  config.gem 'calendar_date_select', :version => '1.15'
  config.gem 'rsl-stringex', :lib => 'stringex', :source => "http://gems.github.com"
  config.gem 'chronic' #required for whenever
  config.gem 'javan-whenever', :lib => false, :source => 'http://gems.github.com'
  config.gem 'searchlogic', :version => '>= 2.3.5'
  config.gem 'mislav-will_paginate', :version => '~> 2.3.11', :lib => 'will_paginate', :source => 'http://gems.github.com'
  config.gem 'pluginaweek-state_machine', :version => '0.8.0', :lib => 'state_machine', :source => 'http://gems.github.com'

  # Only load the plugins named here, in the order given. By default, all plugins
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]
  config.plugins = [ :all, :resource_controller, :extension_patches ]

  config.extensions = [:all]
  
  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Make Time.zone default to the specified zone, and make Active Record store time values
  # in the database in UTC, and return them converted to the specified local zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  config.time_zone = "Eastern Time (US & Canada)"

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector
  config.active_record.observers = :state_monitor

  # The internationalization framework can be changed to have another default locale (standard is :en) or more load paths.
  # All files from config/locales/*.rb,yml are added automatically.
  #config.i18n.load_path << Dir[File.join(RAILS_ROOT, 'my', 'locales', '*.{rb,yml}')]
  config.i18n.default_locale = :'en-US'

end

Time::DATE_FORMATS[:date_time24] = "%Y-%m-%d %H:%M"
Time::DATE_FORMATS[:short_date] = "%Y-%m-%d"

# Add new inflection rules using the following format
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register "application/x-mobile", :mobile

# Include your application configuration below

