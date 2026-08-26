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

            # The owner knows where its own default slots live, and what each
            # of the three flag states means — promote, give up, leave alone.
            def apply_default_flags!(address)
              company = address.owner
              return if company.nil?

              company.assign_default_address(
                address_id: address.id,
                billing: flag_param(:default_billing),
                shipping: flag_param(:default_shipping)
              )
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
