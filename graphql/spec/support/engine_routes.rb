require 'active_support/all'
module EngineRoutes
  extend ActiveSupport::Concern

  included do
    routes { Spree::Core::Engine.routes }
  end
end

RSpec.configure do |config|
  config.include EngineRoutes, type: :controller
end
