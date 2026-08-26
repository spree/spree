module Spree
  module Api
    module V3
      module Store
        module Companies
          # The node's address book, managed by its members. Every entry is
          # reached through its node, so standing over that node is the only
          # thing that authorizes reading or writing one.
          class AddressesController < BaseController
            include Spree::Api::V3::Store::Concerns::CompanyAddressDefaults

            # POST /api/v3/store/companies/:company_id/addresses
            def create
              address = @parent.addresses.new(permitted_params)

              if address.save
                apply_default_flags!(address)
                render json: serialize_resource(address), status: :created
              else
                render_validation_error(address.errors)
              end
            end

            # PATCH /api/v3/store/companies/:company_id/addresses/:id
            def update
              if @resource.update(permitted_params)
                apply_default_flags!(@resource)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            # DELETE /api/v3/store/companies/:company_id/addresses/:id
            def destroy
              @resource.destroy!
              head :no_content
            rescue ActiveRecord::RecordNotDestroyed => e
              render_validation_error(e.record.errors.presence || e.message)
            end

            protected

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.address_serializer
            end

            # Reading a book and keeping one are different rights.
            #
            # Listing shows the node's own sites plus the ones it inherits —
            # the same self-and-ancestors chain its default address is
            # prefilled from, and the same one checkout accepts an id from, so
            # a division ships to its headquarters' addresses.
            #
            # Writing stays with the node that owns the row. Standing over a
            # division is not standing over its parent, and the Store API
            # authorizes purely by what this scope returns — so widening it for
            # every action would let a division member rename, delete, or
            # re-point the defaults of the company above them.
            def scope
              return @parent.addresses unless action_name == 'index'

              Spree::Address.where(owner_type: 'Spree::Company', owner_id: @parent.self_and_ancestors.map(&:id))
            end

            def parent_association
              :addresses
            end

            def permitted_params
              params.permit(:label, *Spree::Api::V3::AddressParams::ADDRESS_KEYS)
            end
          end
        end
      end
    end
  end
end
