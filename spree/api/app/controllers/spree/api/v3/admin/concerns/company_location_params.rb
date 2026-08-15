module Spree
  module Api
    module V3
      module Admin
        module Concerns
          # Shared by the two places a branch is written: nested creation under a
          # company, and direct edits by branch id.
          module CompanyLocationParams
            extend ActiveSupport::Concern

            # Enumerated rather than borrowing the legacy global list, which
            # permits :id, :user_id and :deleted_at.
            ADDRESS_KEYS = [
              :first_name, :last_name, :company, :address1, :address2, :city,
              :postal_code, :zipcode, :phone, :country_iso, :state_code, :state_name, :label
            ].freeze

            protected

            def permitted_params
              params.permit(
                :name, :external_id,
                metadata: {},
                billing_address: ADDRESS_KEYS,
                shipping_address: ADDRESS_KEYS
              )
            end
          end
        end
      end
    end
  end
end
