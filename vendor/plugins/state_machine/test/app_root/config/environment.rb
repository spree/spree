require 'config/boot'

Rails::Initializer.run do |config|
  config.cache_classes = false
  config.whiny_nils = true
  config.active_record.observers = :switch_observer
end
