require 'spree_core'
require 'httparty'

module Spree
  module Dash

  end
end

require 'spree/dash/engine'
require 'spree/dash/jirafe'

# add helper to all the base controllers
# Spree::BaseController includes Spree::Core::ControllerHelpers
require 'spree/core/controller_helpers'
class << Spree::Core::ControllerHelpers
  def included_with_analytics(receiver)
    included_without_analytics(receiver)
    receiver.send :helper, 'spree/analytics'
  end
  alias_method_chain :included, :analytics
end
