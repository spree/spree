# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One entry of a marketplace-owned vocabulary — why goods came back,
        # or what went wrong with a delivery.
        #
        # One serializer for both, unlike the store and admin branches, which
        # keep ReturnReason and ClaimReason apart so Typelizer emits a concrete
        # type per endpoint. Here the two endpoints answer the same shape — a
        # name and whether it is still offered — and the panel renders them
        # through one picker, so a single `Reason` type is what the client
        # actually wants. Read-only, so nothing here is writable.
        class ReasonSerializer < V3::BaseSerializer
          typelize name: :string, active: :boolean

          attributes :name, :active
        end
      end
    end
  end
end
