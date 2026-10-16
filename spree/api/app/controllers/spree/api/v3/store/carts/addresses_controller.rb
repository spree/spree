module Spree
  module Api
    module V3
      module Store
        module Carts
          # Every address this cart may be shipped or billed to, in one call:
          # the buyer's own book, plus the book of the company the cart is for
          # — that node's entries and the ones it inherits from the nodes above
          # it.
          #
          # A checkout address step would otherwise have to reassemble the list
          # itself, from the memberships, the company and the personal book,
          # and reimplement the server's resolution of which company an
          # unstated purchase is for. Asking the cart keeps the picker and the
          # writer that accepts the chosen id from ever disagreeing.
          class AddressesController < Store::ResourceController
            include Spree::Api::V3::CartResolvable

            protected

            def set_parent
              @parent = @cart = find_cart
            end

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.address_serializer
            end

            def parent_association
              :selectable_addresses
            end
          end
        end
      end
    end
  end
end
