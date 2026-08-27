module Spree
  module Api
    module V3
      module Store
        module Companies
          # The node's address book, managed by its members. Every entry is
          # reached through its node, so standing over that node is the only
          # thing that authorizes reading or writing one.
          class AddressesController < BaseController
            include Spree::Api::V3::CompanyAddressWrites

            # POST /api/v3/store/companies/:company_id/addresses
            def create
              result = Spree.address_create_service.call(
                address_params: permitted_params,
                owner: @parent,
                **default_flags
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_validation_error(result.value.errors)
              end
            end

            # PATCH /api/v3/store/companies/:company_id/addresses/:id
            def update
              result = Spree.address_update_service.call(
                address: @resource,
                address_params: permitted_params,
                **default_flags
              )

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_validation_error(result.value.errors)
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

            # Reading a book and keeping one are different rights: the listing
            # includes what this node inherits, writes stay with the node that
            # owns the row. The Store API authorizes purely by what this scope
            # returns, so widening it for every action would let a division
            # member rename or re-point its parent's entries.
            def scope
              action_name == 'index' ? @parent.address_book : @parent.addresses
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
