# Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
require File.join(File.dirname(__FILE__), 'boot')

Spree::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use (only works if using vendor/rails).
  # To use Rails without a database, you must remove the Active Record framework
  # config.frameworks -= [ :action_web_service, :action_mailer ]
  
  # Only load the plugins named here, in the order given. By default, all plugins 
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]
  
  # Only load the extensions named here, in the order given. By default all 
  # extensions in vendor/extensions are loaded, in alphabetical order. :all 
  # can be used as a placeholder for all extensions not explicitly named. 
  # config.extensions = [ :all ] 

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug
  
  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => '_spree_session',
    :secret      => 'asdfqwerfxcoivswqenadfasdfqewpfioutyqwel'
  }
  
  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with 'rake db:sessions:create')
  #config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql
  
  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/fragment_cache"
  config.action_controller.page_cache_directory = "#{RAILS_ROOT}/cache"
  
  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  #config.active_record.default_timezone = :utc
  
end

require 'active_merchant'
require 'has_many_polymorphs'
require 'mini_magick'

# Include your application configuration below

# Spree Configuration
SESSION_KEY = '_spree_session_id'
SHIPPING_METHODS = [:flat_rate]
FLAT_SHIPPING_RATE = 10 # applies only to the flat rate shipping option
ORDER_FROM = "orders@example.com"
ORDER_BCC = []

#ORDER_STATES = [:authorized, :captured, :shipped, :canceled, :returned, :no_charge]
#TXN_TYPES = [:authorize, :capture, :purchase, :credit, :void, :ship, :comp]

#AVAILABLE_ACTIONS = {
#  :authorized => [:capture, :cancel],
#  :captured => [:ship, :cancel],
#  :shipped => [:return, :cancel],
#  :canceled => [],
#  :no_charge => [:ship, :cancel],
#  :returned => []
#}

TXN_TYPES = [:authorize, :capture, :purchase, :void, :credit]

ORDER_STATES = [:incomplete, :authorized, :captured, :canceled, :returned, :shipped, :paid]
ORDER_OPERATIONS = [:authorize, :capture, :cancel, :return, :ship, :comp, :delete]

AVAILABLE_OPERATIONS = {
  :incomplete => [:delete],
  :authorized => [:capture, :ship, :cancel],
  :captured => [:ship, :cancel],
  :canceled => [],
  :returned => [],
  :shipped => [:return, :cancel],
  :paid => [:ship, :cancel]
}

INVENTORY_STATES = [:on_hand, :sold, :shipped, :back_ordered]