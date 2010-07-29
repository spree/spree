require "spree_api"
require "spree_api_hooks"

module SpreeApi
  class Engine < Rails::Engine
    config.autoload_paths += %W(#{config.root}/lib)
  end
end
