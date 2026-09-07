module Spree
  module Api
    module V3
      module Admin
        # Admin-only: who the merchant buys from is never a storefront
        # concern.
        class SupplierSerializer < V3::BaseSerializer
          typelize name: :string,
                   contact_name: 'string | null',
                   email: 'string | null',
                   phone: 'string | null',
                   notes: 'string | null',
                   address1: 'string | null',
                   address2: 'string | null',
                   city: 'string | null',
                   state_name: 'string | null',
                   state_code: 'string | null',
                   country_code: 'string | null',
                   postal_code: 'string | null',
                   purchase_orders_count: :number,
                   deleted_at: 'string | null',
                   metadata: 'Record<string, unknown>'

          attributes :name, :contact_name, :email, :phone, :notes,
                     :address1, :address2, :city, :state_name, :state_code,
                     :country_code, :postal_code, :metadata,
                     created_at: :iso8601, updated_at: :iso8601, deleted_at: :iso8601

          attribute :purchase_orders_count do |supplier|
            supplier.purchase_orders.size
          end
        end
      end
    end
  end
end
