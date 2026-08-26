module Spree
  module Api
    module V3
      module Admin
        module Concerns
          # Shared by the two places an address-book entry is written: nested
          # creation under a company, and direct edits by entry id.
          #
          # An entry is an ordinary address owned by the node, so the payload is
          # address attributes plus the label it is filed under. The two default
          # flags are not columns on the row — they are pointers on the node —
          # so they are applied after the save.
          module CompanyAddressParams
            extend ActiveSupport::Concern

            protected

            def permitted_params
              params.permit(:label, *Spree::Api::V3::AddressParams::ADDRESS_KEYS)
            end

            # The default flags are pointers on the node, not columns on the
            # row, so they are applied once the address itself has been written.
            def save_and_render(resource, status: :ok)
              saved = resource.save
              apply_default_flags!(resource) if saved

              if saved
                render json: serialize_resource(resource.reload), status: status
              else
                render_errors(resource.errors)
              end
            end

            # Promotion goes through the owner, which knows where its own
            # default slots live. Clearing stays here: it is an admin edit with
            # no counterpart on the customer's book, and it only unsets the
            # pointer when this row is the one holding it — another entry's
            # default is not this request's business.
            def apply_default_flags!(address)
              company = address.owner
              return if company.nil?

              billing = flag_param(:default_billing)
              shipping = flag_param(:default_shipping)

              if billing || shipping
                company.assign_default_address(address_id: address.id, billing: !!billing, shipping: !!shipping)
              end

              cleared = {}
              cleared[:default_bill_address_id] = nil if billing == false &&
                                                         company.default_address_id(:bill) == address.id
              cleared[:default_ship_address_id] = nil if shipping == false &&
                                                         company.default_address_id(:ship) == address.id

              company.update!(cleared) if cleared.any?
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
