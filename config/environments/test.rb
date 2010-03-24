# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

# prevents rails 2.1 from complaining about protect_from_forgery while running rspec tests
config.action_controller.allow_forgery_protection = false

config.gem "shoulda", :lib => "shoulda", :version => "2.10.2"
config.gem "factory_girl", :lib => "factory_girl", :version => "1.2.3"
config.gem 'test-unit', :lib => 'test/unit', :version => '~>2.0.5' if RUBY_VERSION.to_f >= 1.9
