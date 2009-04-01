
config.cache_classes = ENV['PRODUCTION']
config.whiny_nils = true
config.action_controller.consider_all_requests_local = !ENV['PRODUCTION']
config.action_controller.perform_caching = ENV['PRODUCTION']
# The following has been deprecated in Rails 2.1 and removed in 2.2
config.action_view.cache_template_extensions = ENV['PRODUCTION'] if Rails::VERSION::MAJOR < 2 or Rails::VERSION::MAJOR == 2 && Rails::VERSION::MINOR < 1
config.action_view.debug_rjs = !ENV['PRODUCTION']
config.action_mailer.raise_delivery_errors = false
