require 'bootstrap-sass/engine'

module SpreeBootstrapFrontend
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_bootstrap_frontend'

    config.autoload_paths += %W(#{config.root}/lib)

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare &method(:activate).to_proc
  end
end
