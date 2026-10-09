module Spree
  module Api
    module V3
      module Admin
        class StoreController < Admin::BaseController
          scoped_resource :settings

          # Reading the current store is shell data — the dashboard needs the
          # name, logo, timezone, currency and locales to render anything at
          # all, so every signed-in staff member can read it regardless of
          # their permissions. Secret keys still need `read_settings`: a
          # scope-limited integration has no business reading operational
          # settings (support/notification emails, routing) it wasn't granted.
          # Writing always requires `write_settings`.
          skip_scope_check! only: :show, jwt_only: true

          # GET /api/v3/admin/store
          def show
            authorize! :show, current_store
            render json: serialize_store
          end

          # PATCH /api/v3/admin/store
          def update
            authorize! :update, current_store

            if current_store.update(permitted_params)
              render json: serialize_store
            else
              render_validation_error(current_store.errors)
            end
          end

          # GET /api/v3/admin/store/data_sources
          #
          # The pricing and inventory engines this store can choose between,
          # with whether each is usable — a provider whose integration is not
          # connected is listed but not selectable, so the dashboard can say
          # why rather than hiding it.
          def data_sources
            authorize! :show, current_store

            render json: {
              data: {
                pricing_providers: describe(Spree.pricing_providers),
                inventory_providers: describe(Spree.inventory_providers),
                failure_policies: Spree::ProviderFailurePolicy::VALUES
              }
            }
          end

          private

          def describe(provider_classes)
            provider_classes.map do |provider_class|
              {
                key: provider_class.key,
                name: provider_class.provider_name,
                integration_type: provider_class.integration_class.presence&.safe_constantize&.api_type,
                available: provider_class.available_for_store?(current_store)
              }
            end
          end

          def serialize_store
            serializer_class.new(current_store, params: serializer_params).to_h
          end

          def serializer_class
            Spree.api.admin_store_serializer
          end

          def permitted_params
            params.permit(
              :name,
              :admin_locale,
              :timezone,
              :weight_unit,
              :unit_system,
              :storefront_access,
              :storefront_url,
              :guest_checkout,
              :always_include_confirm_step,
              :company_field_enabled,
              :address_requires_company,
              :address_requires_phone,
              :capture_method,
              :track_inventory_levels,
              :stock_reservations_enabled,
              :low_stock_threshold,
              :tax_using_ship_address,
              :track_price_history,
              :show_products_without_price,
              :disable_sku_validation,
              :order_routing_strategy,
              :pricing_provider,
              :inventory_provider,
              :pricing_provider_failure_policy,
              :inventory_provider_failure_policy,
              :payout_provider,
              :default_payouts_schedule_interval,
              :default_minimum_payout_amount,
              :auto_approve_sellers,
              :auto_approve_seller_products,
              :send_seller_transactional_emails,
              :default_commission_tax_rate,
              :document_number_format,
              :order_number_prefix,
              :order_number_suffix,
              :order_number_sequence_start,
              :mail_from_address,
              :customer_support_email,
              :new_order_notifications_email,
              :send_consumer_transactional_emails,
              :email_accent_color,
              :email_background_color,
              :email_card_color,
              :email_text_color,
              :email_heading_color,
              :email_font,
              :mailer_logo
            )
          end
        end
      end
    end
  end
end
