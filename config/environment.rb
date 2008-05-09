# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.0.2' unless defined? RAILS_GEM_VERSION

# Specifies gem version of Spree to use when vendor/spree is not present
#SPREE_GEM_VERSION = '0.0.9' unless defined? SPREE_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

#required for engines
#require File.join(File.dirname(__FILE__), '../vendor/plugins/engines/boot')

Spree::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here
  
  # Skip frameworks you're not going to use (only works if using vendor/rails)
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Only load the plugins named here, by default all plugins in vendor/plugins are loaded
  # config.plugins = %W( exception_notification ssl_requirement )
  
  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  #config.action_controller.session_store = :active_record_store
  
  # Don't worry, this info will be project specific when using the gem to create your own app
  config.action_controller.session = {
    :session_key => '_starter_session',
    :secret      => 'ae39bf980cd5709cc313e152d9997fb4f5b944845622f15e61fc4fc6323501c8e0c94a2e2017b76ef4e3b5d4cc3610303cdaee2e15068d4b45a000307e457551'
  }
  
  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper, 
  # like if you have constraints or database-specific column types
  config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # See Rails::Configuration for more options
  
end

require 'active_merchant'
require 'has_many_polymorphs'
require 'mini_magick'

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

# Spree Configuration
SESSION_KEY = '_spree_session_id'
TAX_CALCULATOR = "SalesTax" # feel free to replace with a custom tax calculator class
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

# Ignored unless using the SalesTax calculator
SALES_TAX_RATES = {:NY => 0.08375}

# $$$$$$$$$$ Payment Gateway Settings $$$$$$$$$$ 
# 
# These settings are temporarily being ignored.  Settings will eventually be configured
# in the admin interface once work on the PaymentGateway extension is completed.  For 
# now, the Spree::BogusGateway is always used no matter which environment you're in.
#
# ================================================================================
# LINKPOINT 
# 
# NOTE: Requires the PEM file provided by Linkpoint 
# ================================================================================ 
#PAYMENT_GATEWAY = "ActiveMerchant::Billing::LinkpointGateway"
#GATEWAY_OPTIONS = {:login => "1909543518"}
#ActiveMerchant::Billing::LinkpointGateway.pem_file = File.read( File.dirname(__FILE__) + '/../1909543518.pem' ) # Required for LinkPoint
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

