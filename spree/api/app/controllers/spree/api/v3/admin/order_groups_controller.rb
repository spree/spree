module Spree
  module Api
    module V3
      module Admin
        # The multi-order transaction container — what a customer bought in one
        # checkout when it was fulfilled by more than one seller.
        #
        # Read-only, enforced by the routes: a group records a checkout that
        # already happened, and everything an operator can act on lives on the
        # orders inside it or on the payment it holds.
        class OrderGroupsController < ResourceController
          scoped_resource :orders

          protected

          def model_class
            Spree::OrderGroup
          end

          def serializer_class
            Spree.api.admin_order_group_serializer
          end

          def scope
            super.where(store_id: current_store.id)
          end

          # Everything both serializers touch. The group's figures are summed
          # from its children and its payments are rendered in full, so a page
          # of groups that did not preload them would issue a query per row for
          # each.
          def collection_includes
            [
              :customer, :ship_address, :bill_address,
              { payments: %i[payment_method source] },
              { orders: %i[market gift_card] }
            ]
          end
        end
      end
    end
  end
end
