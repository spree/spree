module Spree
  module Api
    module V3
      module Store
        # A store-owned vocabulary a customer picks from when sending something
        # back or reporting a problem. Read-only and active rows only: the
        # merchant decides what the reasons are, and a retired one is not
        # offered.
        #
        # Subclasses name the model and its serializer.
        class ReasonsController < Store::ResourceController
          protected

          def store_scope
            super.active
          end
        end
      end
    end
  end
end
