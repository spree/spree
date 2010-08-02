require "spree_promotions"

module SpreePromotions
  class Engine < Rails::Engine
    config.autoload_paths += %W(#{config.root}/lib)
  end
end
