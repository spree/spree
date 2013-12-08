require 'spree/core/controller_helpers/common'
require 'spree/core/controller_helpers/auth'
require 'spree/core/controller_helpers/respond_with'
require 'spree/core/controller_helpers/order'

module Spree
  module Core
    module ControllerHelpers
      def self.included(klass)
        klass.class_eval do
          include Spree::Core::ControllerHelpers::Common
          include Spree::Core::ControllerHelpers::Auth
          include Spree::Core::ControllerHelpers::RespondWith
          include Spree::Core::ControllerHelpers::Order
        end
      end
    end
  end
end
