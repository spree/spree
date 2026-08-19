require 'rails/engine'

module SpreeAvalara
  class Engine < Rails::Engine
    engine_name 'spree_avalara'

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
