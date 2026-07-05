module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CustomerGroup for the admin pickers
        # (e.g. promotion rule, customer-group filters). Surfaces only
        # what the admin UI needs to display + select rows.
        class CustomerGroupSerializer < V3::BaseSerializer
          typelize name: :string,
                   description: 'string | null',
                   customers_count: :number

          attributes :name, :description, :customers_count,
                     created_at: :iso8601, updated_at: :iso8601

          # Members are paginated separately via `/customers?customer_group_id_in=…`
          # because a group can hold tens of thousands of users — embedding the
          # whole list on every group fetch would explode the index payload.
          # Pass `expand=customers` when you need them inline (single-record reads only).
          many :customers,
               resource: proc { Spree.api.admin_customer_serializer },
               if: proc { expand?('customers') }
        end
      end
    end
  end
end
