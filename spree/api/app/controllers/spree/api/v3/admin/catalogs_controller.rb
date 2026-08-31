module Spree
  module Api
    module V3
      module Admin
        # Catalogs — assortment + optional price list, shown to an audience
        # through assignments. Merchandising data, so it answers to the
        # products scopes.
        class CatalogsController < ResourceController
          scoped_resource :products

          before_action :set_resource,
                        only: [:show, :update, :destroy, :assign, :import_products]

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
            [:catalog_products, :price_list, :order_minimums]
          end

          def create_workflow
            Spree.catalog_create_workflow
          end

          def update_workflow
            Spree.catalog_update_workflow
          end

          # `price_list` is an inline payload rather than a reference: a
          # catalog and the list it prices through are stood up in one
          # request (docs/plans/6.0-catalog-agreement-rework.md). Sending it
          # as `null` detaches the list the catalog owns; omitting the key
          # leaves it alone.
          def permitted_params
            permitted = params.permit(*model_additional_permitted_attributes,
                                      :name, :description, :active, :position, :price_list_id,
                                      :minimum_order_quantity, :order_multiple,
                                      metadata: {},
                                      # Small bounded sets, saved with the
                                      # catalog so the whole agreement lands
                                      # in one transaction. Per-product terms
                                      # stay their own endpoint — an
                                      # agreement may name thousands of them.
                                      assignments: [:assignable_type, :assignable_id],
                                      order_minimums: [:currency, :amount],
                                      price_list: [
                                        :name, :description, :status, :match_policy,
                                        :starts_at, :ends_at,
                                        :price_adjustment_percentage, :adjust_compare_at,
                                        # Contextual rules only in practice — a
                                        # VolumeRule is what turns a percentage
                                        # into automatic volume pricing. Audience
                                        # rules on an owned list are inert, since
                                        # the catalog assignment already decided
                                        # the audience.
                                        { rules: [:id, :type, { preferences: {} }] },
                                        # An empty array clears the hand-entered
                                        # amounts — what switching to a
                                        # percentage sends.
                                        { prices: [:id, :variant_id, :currency, :amount,
                                                   :compare_at_amount] }
                                      ])
            if permitted.key?(:price_list_id)
              permitted[:price_list_id] =
                if permitted[:price_list_id].present?
                  current_store.price_lists.find_by_prefix_id!(permitted[:price_list_id]).id
                else
                  nil
                end
            end
            # `permit` drops an explicit null, but detaching has to be
            # distinguishable from saying nothing.
            permitted[:price_list] = nil if params.key?(:price_list) && params[:price_list].nil?

            # Resolved here rather than in the workflow: each audience goes
            # through the store AND through what this caller may see, so a
            # nested write cannot reach one the dedicated endpoint could not.
            if permitted.key?(:assignments)
              permitted[:assignables] = requested_assignables
              permitted.delete(:assignments)
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
            resolve_assignable(params.require(:assignable_type), params.require(:assignable_id))
          end

          # Each entry resolves the same way a single assign does — through
          # the store AND through what this caller may see — so a set write
          # cannot reach an audience the one-at-a-time path could not.
          def requested_assignables
            Array(params[:assignments]).map do |entry|
              permitted = entry.permit(:assignable_type, :assignable_id)
              resolve_assignable(permitted.require(:assignable_type), permitted.require(:assignable_id))
            end
          end

          def resolve_assignable(type, id)
            scope_builder = ASSIGNABLE_SCOPES[type.to_s]
            raise ActiveRecord::RecordNotFound if scope_builder.nil?

            scope_builder.call(current_store).
              accessible_by(current_ability, :show).
              find_by_prefix_id!(id)
          end
        end
      end
    end
  end
end
