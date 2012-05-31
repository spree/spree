require 'spree_core'
require 'httparty'

module Spree
  module Dash

  end
end

require 'spree/dash/engine'
require 'spree/dash/jirafe'

Spree::BaseController.send :helper, 'spree/analytics'
