module Spree
  module Api
    module V3
      module Seller
        # A marketplace-owned vocabulary a seller picks from — why goods came
        # back, or what went wrong with a delivery.
        #
        # Read-only, because the vocabulary is the operator's to define: a
        # seller chooses a reason, never adds one. Gated by `orders` rather
        # than `settings` — a seller reads these to fill in a form on their own
        # order, and `settings` is closed to the seller audience entirely.
        #
        # Store-scoped rather than seller-scoped, since these are the store's
        # own rows. Retired reasons are left out so a seller cannot file
        # against vocabulary the operator has withdrawn.
        #
        # Subclasses name the model and the association to read it through.
        class ReasonsController < Seller::ResourceController
          scoped_resource :orders

          protected

          def serializer_class
            Spree.api.seller_reason_serializer
          end

          def read_actions
            %w[index]
          end

          def scope
            current_store.public_send(reasons_association).active
          end

          # The store association holding this vocabulary.
          #
          # @return [Symbol]
          def reasons_association
            raise NotImplementedError
          end
        end
      end
    end
  end
end
