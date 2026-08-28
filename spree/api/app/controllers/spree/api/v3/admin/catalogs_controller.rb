module Spree
  module Api
    module V3
      module Admin
        # Catalogs — assortment + optional price list, shown to an audience
        # through assignments. Merchandising data, so it answers to the
        # products scopes.
        class CatalogsController < ResourceController
          scoped_resource :products

          before_action :set_resource, only: [:show, :update, :destroy, :assign, :import_products]

          # POST /api/v3/admin/catalogs/:id/import_products — copies the
          # attached price list's products into the assortment. Explicit by
          # design: an empty assortment is a pricing-only overlay, so making
          # a catalog restrictive is a deliberate act.
          def import_products
            authorize! :update, @resource

            if @resource.price_list.nil?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('catalogs.no_price_list_to_import'),
                status: :unprocessable_content
              )
            end

            render json: { added_count: @resource.import_products_from_price_list }
          end

          # POST /api/v3/admin/catalogs/:id/assign — { assignable_type, assignable_id }
          def assign
            authorize! :update, @resource

            assignment = @resource.catalog_assignments.new(assignable: find_assignable)

            if assignment.save
              render json: Spree.api.admin_catalog_assignment_serializer.new(
                assignment, params: serializer_params
              ).to_h, status: :created
            else
              render_validation_error(assignment.errors)
            end
          end

          protected

          def model_class
            Spree::Catalog
          end

          def serializer_class
            Spree.api.admin_catalog_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def collection_includes
            [:catalog_products, :price_list]
          end

          def permitted_params
            permitted = params.permit(*model_additional_permitted_attributes,
                                      :name, :active, :position, :price_list_id, metadata: {})
            if permitted.key?(:price_list_id)
              permitted[:price_list_id] =
                if permitted[:price_list_id].present?
                  current_store.price_lists.find_by_prefix_id!(permitted[:price_list_id]).id
                else
                  nil
                end
            end
            permitted
          end

          private

          # The audience vocabulary is closed; each type resolves through the
          # store so another tenant's record is a 404, never an assignment.
          ASSIGNABLE_SCOPES = {
            'company' => ->(store) { store.companies },
            'customer_group' => ->(store) { Spree::CustomerGroup.for_store(store) }
          }.freeze

          # Scoped by the store AND by what this caller may see: a role that
          # reaches only some companies must not be able to assign a catalog
          # to one it cannot read, and an unreadable record is not-found
          # rather than refused so its existence does not leak.
          def find_assignable
            scope_builder = ASSIGNABLE_SCOPES[params.require(:assignable_type).to_s]
            raise ActiveRecord::RecordNotFound if scope_builder.nil?

            scope_builder.call(current_store).
              accessible_by(current_ability, :show).
              find_by_prefix_id!(params.require(:assignable_id))
          end
        end
      end
    end
  end
end
