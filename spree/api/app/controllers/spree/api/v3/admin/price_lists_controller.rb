module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::PriceList`, plus the lifecycle transitions
        # (`activate` / `deactivate`).
        #
        # Everything writable on the list itself — name, schedule, match
        # policy, nested rules (`rules: [...]`), and individual price
        # overrides (`prices: [...]`) — flows through the regular PATCH
        # payload. Product membership lives on the uniform nested surface
        # (PriceLists::ProductsController), the same protocol categories,
        # collections and catalogs use.
        #
        # Scoped under the `products` API-key scope — price lists are a
        # product/pricing concern; we don't introduce a separate
        # `read_price_lists` scope.
        class PriceListsController < ResourceController
          scoped_resource :products

          # The base ResourceController limits `set_resource` to
          # `show/update/destroy`. We need it on the custom member
          # actions below too, so swap in our own filter — Rails keys
          # before_actions by method name, so this would otherwise
          # *replace* the parent's narrower filter and break the standard
          # actions. Wrapping it under a different name keeps both.
          before_action :load_member_resource, only: [:activate, :deactivate]

          # GET /api/v3/admin/price_lists/price_rule_types
          #
          # Returns `[{ type, label, description, schema }]`
          # for every registered subclass in `Spree.pricing.rules`. The
          # SPA uses this to build the "Add rule" picker + render a
          # generic preferences form per subclass. Rules themselves are
          # not a separate REST resource — they ride along on the price
          # list's PATCH body via `rules: [...]`.
          def price_rule_types
            authorize! :read, Spree::PriceRule
            render json: { data: Spree::PriceRule.subclasses_with_preference_schema }
          end

          # PATCH /api/v3/admin/price_lists/:id/activate
          #
          # draft|inactive → active, or → scheduled when `starts_at` is in the
          # future. The workflow decides which, so a caller never has to.
          def activate
            authorize! :update, @resource

            result = Spree.price_list_activate_workflow.call(price_list: @resource)

            if result.success?
              render json: serialize_resource(@resource)
            else
              render_service_error(result.error)
            end
          end

          # PATCH /api/v3/admin/price_lists/:id/deactivate
          def deactivate
            authorize! :update, @resource

            result = Spree.price_list_deactivate_workflow.call(price_list: @resource)

            if result.success?
              render json: serialize_resource(@resource)
            else
              render_service_error(result.error)
            end
          end

          protected

          def model_class
            Spree::PriceList
          end

          def serializer_class
            Spree.api.admin_price_list_serializer
          end

          def create_workflow
            Spree.price_list_create_workflow
          end

          def update_workflow
            Spree.price_list_update_workflow
          end

          def scope
            super.ordered
          end

          # The serializer always renders a list's bands — the pricing card
          # cannot show a percentage without them — so the index preloads them
          # rather than paying a query per row.
          def collection_includes
            [:price_adjustment_tiers]
          end

          def permitted_params
            normalize_params(
              params.permit(
                *model_additional_permitted_attributes,
                :name, :description, :position,
                :starts_at, :ends_at, :match_policy,
                :price_adjustment_percentage, :adjust_compare_at,
                rules: [:id, :type, { preferences: {} }],
                price_adjustment_tiers: [:min_quantity, :percentage],
                prices: [:id, :variant_id, :currency, :min_quantity, :amount, :compare_at_amount]
              )
            )
          end

          private

          # Loads the record without the action-derived authorization
          # `set_resource` runs (which would check `:activate` /
          # `:deactivate` — actions that abilities don't grant). The
          # per-action methods explicitly call `authorize!` with
          # `:update`, which ability rules actually mention.
          def load_member_resource
            @resource = find_resource
          end
        end
      end
    end
  end
end
