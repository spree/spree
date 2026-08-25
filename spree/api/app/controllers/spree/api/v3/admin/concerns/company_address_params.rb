module Spree
  module Api
    module V3
      module Admin
        module Concerns
          # Shared by the two places an address-book entry is written: nested
          # creation under a company, and direct edits by entry id.
          module CompanyAddressParams
            extend ActiveSupport::Concern

            protected

            def permitted_params
              params.permit(
                :label, :default_billing, :default_shipping,
                address: Spree::Api::V3::AddressParams::ADDRESS_KEYS
              )
            end
          end
        end
      end
    end
  end
end
