module Spree
  module Api
    module V3
      module Admin
        # Catalogs — assortment + optional price list, shown to an audience
        # through assignments. Merchandising data, so it answers to the
        # products scopes.
        class CatalogsController < ResourceController
          ASSIGNMENT = Spree::Api::V3::RequestSchema.shape('CatalogAssignmentParams') do |schema|
            schema.attribute :assignable_type, :string,
              required: true,
              choices: %w[customer_group company],
              example: 'company',
              description: 'Buyer audiences only. A company assignment covers its subtree.'
            schema.attribute :assignable_id, :id, required: true, example: 'comp_86Rf07xd4z'
          end

          scoped_resource :products

          before_action :set_resource,
                        only: [:show, :update, :destroy, :assign, :import_products,
                               :activate, :deactivate]

          request_params :catalog do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'VIP Assortment'
            body.attribute :description, :string,
              nullable: true,
              description: 'Internal note on what the agreement is, never shown to shoppers.'
            body.attribute :active, :boolean, example: true
            body.attribute :position, :integer
            body.attribute :minimum_order_quantity, :integer,
              nullable: true,
              description: "The catalog-wide quantity terms, between a variant's own rule and a per-variant override. Null leaves the field to the variant's own rule."
            body.attribute :order_multiple, :integer,
              nullable: true,
              description: "The catalog-wide quantity terms, between a variant's own rule and a per-variant override. Null leaves the field to the variant's own rule."
            body.attribute :metadata, :hash
            # Small bounded sets, saved with the catalog so the whole
            # agreement lands in one transaction. Per-product terms stay their
            # own endpoint: an agreement may name thousands of them.
            body.attribute :assignments, :array, of: ASSIGNMENT,
              description: 'The whole audience. An entry left out is withdrawn; omitting the key leaves the audience alone.'
            body.attribute :order_minimums, :array, of: Spree::Api::V3::Admin::CatalogOrderMinimumRequestSchema,
              description: 'The whole order-minimum set. A currency left out has its minimum lifted; omitting the key leaves them alone.'
            body.attribute :price_list, :object,
              nullable: true,
              as: 'CatalogPriceListParams',
              description: 'The price list this catalog prices through, written inline: an object creates the owned list or updates it. Null deletes the list (a soft delete). Omit the key, or send `{}`, to leave the pricing alone. A catalog with an empty assortment prices without hiding anything; curate or import products to make it restrictive.' do |price_list|
              price_list.attribute :name, :string
              price_list.attribute :description, :string, nullable: true
              price_list.attribute :status, :string
              price_list.attribute :match_policy, :string
              price_list.attribute :starts_at, :datetime, nullable: true
              price_list.attribute :ends_at, :datetime, nullable: true
              price_list.attribute :price_adjustment_percentage, :decimal,
                nullable: true,
                example: '-15.0',
                description: 'Signed: negative discounts off base prices, positive marks up.'
              price_list.attribute :adjust_compare_at, :boolean
              # Audience rules on an owned list are inert, since the catalog
              # assignment already decided the audience.
              price_list.attribute :rules, :array, of: Spree::Api::V3::Admin::PriceListRuleRequestSchema,
                description: "Contextual rules, in practice a `volume_rule`. Audience rules are left as they are, and an empty list clears the contextual rules."
              price_list.attribute :prices, :array, of: Spree::Api::V3::Admin::PriceListPriceRequestSchema,
                description: 'Explicit per-variant amounts. An empty list clears them, which is what switching to a percentage sends.'
              price_list.attribute :price_adjustment_tiers, :array, of: Spree::Api::V3::Admin::PriceAdjustmentTierRequestSchema,
                description: 'Quantity bands on the percentage. The payload is the whole ladder, so an empty list clears it.'
            end
          end

          request_params('CatalogAssignParams', action: :assign) { |body| body.include_attributes ASSIGNMENT }

          # POST /api/v3/admin/catalogs/:id/import_products — copies the
          # attached price list's products into the assortment. Explicit by
          # design: an empty assortment is a pricing-only overlay, so making
          # a catalog restrictive is a deliberate act.
          def import_products
            authorize! :update, @resource

            if @resource.price_list.nil?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: I18n.t('spree.catalogs.no_price_list_to_import'),
                status: :unprocessable_content
              )
            end

            render json: { added_count: @resource.import_products_from_price_list }
          end

          # POST /api/v3/admin/catalogs/:id/assign
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

          # PATCH /api/v3/admin/catalogs/:id/activate
          def activate
            run_status_workflow(Spree.catalog_activate_workflow)
          end

          # PATCH /api/v3/admin/catalogs/:id/deactivate
          def deactivate
            run_status_workflow(Spree.catalog_deactivate_workflow)
          end

          protected

          def model_class
            Spree::Catalog
          end

          def serializer_class
            Spree.api.admin_catalog_serializer
          end

          def scope
            super.ordered
          end

          def collection_includes
            # The serializer reads each catalog's pricing strategy, which asks
            # its list whether it carries bands — preloaded so an index does
            # not pay a query per row.
            [:catalog_products, :order_minimums, { price_list: :price_adjustment_tiers }]
          end

          def create_workflow
            Spree.catalog_create_workflow
          end

          def update_workflow
            Spree.catalog_update_workflow
          end

          def run_status_workflow(workflow)
            authorize! :update, @resource

            result = workflow.call(catalog: @resource)

            if result.success?
              render json: serialize_resource(@resource.reload)
            else
              render_service_error(result.error)
            end
          end

          # `price_list` is an inline payload rather than a reference: a
          # catalog and the list it prices through are stood up in one
          # request (docs/plans/6.0-catalog-agreement-rework.md). Sending it
          # as `null` detaches the list the catalog owns; omitting the key
          # leaves it alone.
          def permitted_params
            permitted = params.permit(*permitted_attributes)
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
