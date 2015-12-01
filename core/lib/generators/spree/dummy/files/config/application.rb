require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.to_prepare do
      # Load all application files in a deterministic order
      Pathname.glob(Rails.root.join(*%w[app ** *.rb])).sort.each do |path|
        ActiveSupport::Dependencies.require_or_load(path.to_s)
      end

      # Eager load all the engine models
      Rails::Engine
        .descendants
        .reject(&:abstract_railtie?)
        .each(&:eager_load!)
    end

    # Set ActiveRecord to store/retrieve all dates and times in UTC
    config.active_record.default_timezone = :utc
  end
end
