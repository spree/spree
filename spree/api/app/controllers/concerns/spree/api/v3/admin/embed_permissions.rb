module Spree
  module Api
    module V3
      module Admin
        # Keeps records another permission guards out of a response.
        #
        # An endpoint is gated on its own resource's key, but expanding an
        # association pulls in whole records of another kind — a customer's
        # orders, an order's payments, a gift card's customer. Without this a
        # role cleared only for customers could read every order through
        # `?expand=orders`. Each segment of an expand path is checked, so
        # `orders.payments` needs both keys.
        #
        # Gift card codes are bearer credentials that ride along on every
        # order, so serializers show them in full only to a caller who may read
        # gift cards and masked to everyone else.
        module EmbedPermissions
          extend ActiveSupport::Concern

          # Association name in an expand path => the catalog key it needs.
          EXPANSION_PERMISSIONS = {
            'order' => 'read_orders',
            'orders' => 'read_orders',
            'payment' => 'read_payments',
            'payments' => 'read_payments',
            'payment_splits' => 'read_payments',
            'customer' => 'read_customers',
            'customers' => 'read_customers',
            'gift_card' => 'read_gift_cards',
            'gift_cards' => 'read_gift_cards',
            'store_credit' => 'read_store_credits',
            'store_credits' => 'read_store_credits'
          }.freeze

          protected

          def expand_list
            super.select { |path| path.split('.').all? { |segment| expansion_permitted?(segment) } }
          end

          def serializer_params
            super.merge(gift_card_codes: holds_permission?('read_gift_cards'))
          end

          private

          def expansion_permitted?(segment)
            key = EXPANSION_PERMISSIONS[segment]
            key.nil? || holds_permission?(key)
          end
        end
      end
    end
  end
end
