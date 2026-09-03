# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One entry of a marketplace-owned vocabulary — why goods came back,
        # or what went wrong with a delivery.
        #
        # One serializer for both: a reason is a name and whether it is still
        # offered, and Spree::ReturnReason and Spree::ClaimReason answer that
        # identically. Read-only on this branch, so nothing here is writable.
        class ReasonSerializer < V3::BaseSerializer
          typelize name: :string, active: :boolean

          attributes :name, :active
        end
      end
    end
  end
end
