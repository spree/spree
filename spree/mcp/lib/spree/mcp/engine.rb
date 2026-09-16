module Spree
  module Mcp
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_mcp'
    end
  end
end
