module Spree
  module Api
    module V3
      # Payload of the supplier.* events. A supplier's contact details stay
      # behind the Admin API.
      class SupplierEventSerializer < BaseSerializer
        typelize name: :string

        attributes :name, created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end
