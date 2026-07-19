module Spree
  module Api
    module V3
      # Minimal customer-group shape for the Store API. Exposed on
      # `customers/me` so a storefront can branch on membership (e.g. an
      # approved wholesale buyer) — pricing itself always resolves
      # server-side.
      class CustomerGroupSerializer < BaseSerializer
        typelize name: :string

        attributes :name
      end
    end
  end
end
