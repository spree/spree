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
          #
          # Signed in only, unlike the rest of the cart surface. What comes
          # back is not the cart's own data but the books behind it — every
          # address the buyer has saved, and their company's sites. A guest
          # token says the caller holds this cart, which it may well do
          # because the account holder adopted a cart the attacker started;
          # it says nothing about the account. A genuine guest cart has
          # neither book, so requiring the account costs nothing but the 401.
          class AddressesController < Store::ResourceController
            include Spree::Api::V3::CartResolvable

            prepend_before_action :require_authentication!

            protected

            def set_parent
              @parent = @cart = find_cart(token: nil)
            end

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.address_serializer
            end

            def collection_includes
              [:owner]
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
