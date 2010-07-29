require "rails/all"
require "spree_core"

module SpreeCore
  class Engine < Rails::Engine
    config.autoload_paths += %W(#{config.root}/lib)
  end
end