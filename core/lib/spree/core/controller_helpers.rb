module Spree
  module Core
    module ControllerHelpers
      def self.included(base)
        base.class_eval do
          include Spree::Core::ControllerHelpers::Common
          include Spree::Core::ControllerHelpers::Auth
          include Spree::Core::ControllerHelpers::Order
        end
      end
    end
  end
end
