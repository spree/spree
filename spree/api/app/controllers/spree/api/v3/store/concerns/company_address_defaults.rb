module Spree
  module Api
    module V3
      module Store
        module Concerns
          # An address-book entry's "is this the default" flags are pointers on
          # the node rather than columns on the row, so they are applied after
          # the address itself is saved. Shared by the two places the storefront
          # writes one: nested creation under a company, and direct edits.
          module CompanyAddressDefaults
            extend ActiveSupport::Concern

            protected

            def apply_default_flags!(address)
              company = address.owner
              return if company.nil?

              attributes = {}
              attributes[:default_bill_address_id] = address.id if flag_param(:default_billing) == true
              attributes[:default_ship_address_id] = address.id if flag_param(:default_shipping) == true
              # Clearing a flag only unsets it when this row is the one holding
              # it — another entry's default is not this request's business.
              attributes[:default_bill_address_id] = nil if flag_param(:default_billing) == false &&
                                                            company.default_bill_address_id == address.id
              attributes[:default_ship_address_id] = nil if flag_param(:default_shipping) == false &&
                                                           company.default_ship_address_id == address.id

              company.update!(attributes) if attributes.any?
            end

            # @return [Boolean, nil] nil when the client said nothing about it
            def flag_param(name)
              return nil unless params.key?(name)

              ActiveModel::Type::Boolean.new.cast(params[name])
            end
          end
        end
      end
    end
  end
end
