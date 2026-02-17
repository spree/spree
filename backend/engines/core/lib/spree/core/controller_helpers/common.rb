module Spree
  module Core
    module ControllerHelpers
      # @deprecated This module is deprecated and will be removed in Spree 5.5.
      module Common
        def self.included(base)
          Spree::Deprecation.warn(
            'Spree::Core::ControllerHelpers::Common is deprecated and will be removed in Spree 5.5.'
          )
        end
      end
    end
  end
end
