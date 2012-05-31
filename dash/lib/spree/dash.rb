require 'spree_core'
require 'httparty'

module Spree
  module Dash

  end
end

require 'spree/dash/engine'
require 'spree/dash/jirafe'

Spree::Dash::Engine.config.to_prepare do
  Spree::BaseController.send :helper, 'spree/analytics'
end
