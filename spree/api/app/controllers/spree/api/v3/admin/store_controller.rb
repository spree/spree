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

          private

          def serialize_store
            serializer_class.new(current_store, params: serializer_params).to_h
          end

          def serializer_class
            Spree.api.admin_store_serializer
          end

          def permitted_params
            params.permit(
              :name,
              :preferred_admin_locale,
              :preferred_timezone,
              :preferred_weight_unit,
              :preferred_default_package_weight,
              :preferred_default_package_length,
              :preferred_default_package_width,
              :preferred_default_package_height,
              :preferred_unit_system,
              :preferred_storefront_access,
              :preferred_storefront_url,
              :preferred_guest_checkout,
              :preferred_company_field_enabled,
              :preferred_address_requires_phone,
              :preferred_capture_method,
              :preferred_track_inventory_levels,
              :preferred_stock_reservations_enabled,
              :preferred_track_price_history,
              :preferred_show_products_without_price,
              :preferred_disable_sku_validation,
              :preferred_order_routing_strategy,
              :preferred_document_number_format,
              :preferred_order_number_prefix,
              :preferred_order_number_suffix,
              :preferred_order_number_sequence_start,
              :mail_from_address,
              :customer_support_email,
              :new_order_notifications_email,
              :preferred_send_consumer_transactional_emails,
              :mailer_logo
            )
          end
        end
      end
    end
  end
end
