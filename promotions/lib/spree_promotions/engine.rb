require "spree_promotions"
require "spree_promotions_hooks"

module SpreePromotions
  class Engine < Rails::Engine
    config.autoload_paths += %W(#{config.root}/lib)
  end
end
