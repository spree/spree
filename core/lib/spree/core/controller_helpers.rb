require 'spree/core/controller_helpers/auth'
require 'spree/core/controller_helpers/common'
require 'spree/core/controller_helpers/order'
require 'spree/core/controller_helpers/respond_with'
require 'spree/core/controller_helpers/store'

module Spree
  module Core
    module ControllerHelpers
      extend ActiveSupport::Concern
      included do
        include Spree::Core::ControllerHelpers::Auth
        include Spree::Core::ControllerHelpers::Common
        include Spree::Core::ControllerHelpers::Order
        include Spree::Core::ControllerHelpers::RespondWith
        include Spree::Core::ControllerHelpers::Store
      end
    end
  end
end
