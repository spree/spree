require File.expand_path("../../../core/lib/spree_core", __FILE__)
require File.expand_path("../../../auth/lib/spree_auth", __FILE__)
require File.expand_path("../spree_api_hooks", __FILE__)

module SpreeApi
  class Engine < Rails::Engine
    engine_name 'spree_api'

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env.production? ? require(c) : load(c)
      end

    end
    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &method(:activate).to_proc
  end
end
