module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::PriceList`, plus the lifecycle transitions
        # (`activate` / `deactivate`) and the spreadsheet's data feed
        # (`prices`).
        #
        # Everything writable on the list — name, schedule, match policy,
        # product membership (`product_ids: [...]`), nested rules
        # (`rules: [...]`), and individual price overrides
        # (`prices: [...]`) — flows through the regular PATCH payload, so
        # the SPA saves the entire editor in one round-trip. No separate
        # add_products / remove_products / add_rule / bulk_update_prices
        # endpoints.
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
          before_action :load_member_resource, only: [:activate, :deactivate, :prices]

          # GET /api/v3/admin/price_lists/price_rule_types
          #
          # Returns `[{ type, label, description, preference_schema }]`
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
          # State transition: draft|inactive → active (or → scheduled when
          # `starts_at` is in the future). Mirrors the old Rails admin's
          # "Activate" button which automatically scheduled future lists.
          def activate
            authorize! :update, @resource
            event = @resource.starts_at.present? && @resource.starts_at.future? ? :schedule : :activate

            if @resource.send(event)
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          # PATCH /api/v3/admin/price_lists/:id/deactivate
          def deactivate
            authorize! :update, @resource

            if @resource.deactivate
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          # GET /api/v3/admin/price_lists/:id/prices
          #
          # The spreadsheet editor's data source. Returns every Price row
          # in this list (filtered by `?currency=`), eager-loading
          # `variant.product` + option values so each cell can render
          # product name, variant options and SKU without N+1.
          def prices
            authorize! :read, @resource
            currency = params[:currency].presence || current_store.default_currency
            prices = @resource.prices
                              .includes(variant: [:product, { option_values: :option_type }])
                              .where(currency: currency)
                              .joins(variant: :product)
                              .order(Arel.sql("#{Spree::Product.table_name}.name ASC"))
                              .order(Arel.sql("#{Spree::Variant.table_name}.position ASC"))

            render json: {
              data: prices.map { |p| serialize_price(p) },
              meta: { currency: currency, count: prices.size }
            }
          end

          protected

          def model_class
            Spree::PriceList
          end

          def serializer_class
            Spree.api.admin_price_list_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def permitted_params
            attrs = normalize_params(
              params.permit(
                :name, :description, :position,
                :starts_at, :ends_at, :match_policy,
                product_ids: [],
                rules: [:id, :type, { preferences: {} }],
                prices: [:id, :variant_id, :currency, :amount, :compare_at_amount]
              )
            )
            reject_foreign_membership(attrs)
          end

          # The PriceList model setters (`product_ids=`, `prices=`) resolve
          # member ids with no store scoping, so a list in this store could
          # otherwise be populated with another store's products/variants.
          # Drop any id that isn't in the current store before assignment.
          def reject_foreign_membership(attrs)
            if attrs[:product_ids].present?
              store_product_ids = current_store.products.where(id: attrs[:product_ids]).pluck(:id).map(&:to_s).to_set
              attrs[:product_ids] = Array(attrs[:product_ids]).select { |id| store_product_ids.include?(id.to_s) }
            end

            if attrs[:prices].present?
              incoming = Array(attrs[:prices])
              store_variant_ids = current_store.variants.where(id: incoming.map { |r| r[:variant_id] }.compact).
                                  pluck(:id).map(&:to_s).to_set
              attrs[:prices] = incoming.select do |row|
                row[:variant_id].blank? || store_variant_ids.include?(row[:variant_id].to_s)
              end
            end

            attrs
          end

          private

          # Loads the record without the action-derived authorization
          # `set_resource` runs (which would check `:activate` /
          # `:deactivate` / `:prices` — actions that abilities don't
          # grant). The per-action methods below explicitly call
          # `authorize!` with the standard action that ability rules
          # actually mention (`:update` / `:read`).
          def load_member_resource
            @resource = find_resource
          end

          # Hand-rolled flat shape for the spreadsheet — keeps the payload
          # narrow (no nested variant/product/option_value objects) and
          # avoids paying for the admin Price serializer when we only need
          # ~6 fields per row. The grouping the UI does (rows → product
          # header) is driven entirely off `product_id`/`product_name`.
          def serialize_price(price)
            variant = price.variant
            product = variant.product
            {
              id: price.prefixed_id,
              variant_id: variant.prefixed_id,
              product_id: product.prefixed_id,
              product_name: product.name,
              variant_label: variant.options_text.presence,
              sku: variant.sku,
              currency: price.currency,
              amount: price.amount&.to_s,
              compare_at_amount: price.compare_at_amount&.to_s
            }
          end

        end
      end
    end
  end
end
