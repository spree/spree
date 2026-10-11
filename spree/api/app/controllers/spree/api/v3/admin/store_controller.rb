module Spree
  module Api
    module V3
      module Admin
        class StoreController < Admin::BaseController
          include Spree::Api::V3::LegacyPreferenceParams

          scoped_resource :settings
          accepts_legacy_preference_params Spree::Store

          request_params :store do
            string :name, example: 'My Store'
            string :admin_locale, example: 'en'
            string :timezone, example: 'Europe/Berlin'
            string :weight_unit, enum: Spree::Variant::WEIGHT_UNITS
            string :unit_system, enum: Spree::Store::UNIT_SYSTEMS
            string :storefront_access, enum: Spree::Channel::Gating::STOREFRONT_ACCESS,
                                       description: "The store-wide default for what anonymous visitors can see. Channels fall back to it when they don't set their own."
            string :storefront_url, nullable: true,
                                    description: "The storefront's public URL, the base for links in customer emails. Saving it also completes the storefront setup task."
            boolean :guest_checkout, description: 'The store-wide default for guest checkout. Channels fall back to it.'
            boolean :always_include_confirm_step,
                    description: 'Always show a confirmation step in checkout, even when no payment method requires one.'
            boolean :company_field_enabled, description: 'Shows a company field on address forms.'
            boolean :address_requires_company, description: 'Makes a company name mandatory on addresses.'
            boolean :address_requires_phone, description: 'Makes a phone number mandatory on customer addresses.'
            string :capture_method, enum: Spree::CaptureMethod::CAPTURE_METHODS,
                                    description: "The store-wide default for when a customer is charged rather than only authorized. A payment method's own setting wins when set."
            boolean :preferred_auto_capture, :preferred_auto_capture_on_dispatch,
                    deprecated: 'Use `capture_method`. Removed in 6.1.'
            boolean :track_inventory_levels,
                    description: 'Counts on-hand quantities. Off means everything is treated as always available.'
            boolean :stock_reservations_enabled,
                    description: "Holds stock for shoppers while they check out, so the same item can't be sold twice."
            integer :low_stock_threshold,
                    description: 'On-hand units at or below which a tracked variant counts as low stock on the home screen; 0 turns the warning off.'
            boolean :tax_using_ship_address,
                    description: 'Calculates tax from the shipping address. When false, tax is calculated from the billing address.'
            boolean :track_price_history,
                    description: 'Records price changes for the EU Omnibus lowest-price-in-30-days display.'
            boolean :show_products_without_price,
                    description: "Whether products with no price in the shopper's currency still appear in listings."
            boolean :disable_sku_validation, description: 'Lets more than one variant share the same SKU.'
            string :order_routing_strategy, description: 'The store-wide order routing strategy shorthand. Channels fall back to it.'
            string :pricing_provider, description: 'Where prices come from: a registered provider key, or `internal`.'
            string :inventory_provider, description: 'Where stock levels come from: a registered provider key, or `internal`.'
            string :pricing_provider_failure_policy, enum: Spree::ProviderFailurePolicy::VALUES,
                                                     description: '`strict` refuses to price when the provider cannot answer; `fallback` uses the catalog.'
            string :inventory_provider_failure_policy, enum: Spree::ProviderFailurePolicy::VALUES,
                                                       description: '`fallback` sells on the local stock snapshot when the provider cannot answer; `strict` refuses.'
            string :payout_provider, description: 'Blank means the built-in provider: the marketplace settles by hand.'
            string :default_payouts_schedule_interval, enum: Spree::Seller::PAYOUT_INTERVALS
            decimal :default_minimum_payout_amount, example: '50.00', description: "In the store's currency."
            boolean :auto_approve_sellers, description: 'Admits a seller as soon as they finish onboarding, with no operator review.'
            boolean :auto_approve_seller_products,
                    description: 'Puts a seller product on sale the moment it is submitted, with no review.'
            boolean :send_seller_transactional_emails,
                    description: 'When false, transactional seller emails (approval, payouts and so on) are not sent.'
            decimal :default_commission_tax_rate, example: '0.23',
                                                  description: 'Tax charged on commission as a fraction (`"0.23"` is 23%), when neither the commission rate nor the tax provider names one.'
            string :document_number_format, example: 'sequential',
                                            description: 'How document numbers are produced: `sequential` or `random`. Applies to every numbered document.'
            string :order_number_prefix, example: 'R',
                                         description: 'Leads every order number. Uppercase letters, digits, dashes and # only.'
            string :order_number_suffix, description: 'Ends every order number. Uppercase letters, digits, dashes and # only.'
            integer :order_number_sequence_start,
                    description: "The first sequential order number. Only applies before the store's first order."
            boolean :limit_digital_download_count, description: 'Whether a digital download link stops working after a number of clicks.'
            integer :digital_asset_authorized_clicks, description: 'How many clicks a download link allows, unless the file sets its own.'
            boolean :limit_digital_download_days, description: 'Whether a digital download link expires after a number of days.'
            integer :digital_asset_authorized_days, description: 'How many days a download link stays valid, unless the file sets its own.'
            string :mail_from_address, description: 'Sender address of every transactional email.'
            string :customer_support_email, nullable: true,
                                            description: 'Customer-facing reply-to address shown in the storefront and email footers.'
            string :new_order_notifications_email, nullable: true,
                                                   description: 'Recipient of "new order placed" staff notifications.'
            boolean :send_consumer_transactional_emails,
                    description: 'When false, transactional customer emails (order confirmation and so on) are not sent.'
            string :email_accent_color, nullable: true,
                                        description: 'Customer email buttons and links, as `#RRGGBB`. Blank keeps the outlined buttons emails ship with.'
            string :email_background_color, nullable: true, description: 'Customer email page background, as `#RRGGBB`.'
            string :email_card_color, nullable: true, description: 'Customer email card behind the content, as `#RRGGBB`.'
            string :email_text_color, nullable: true, description: 'Customer email body text, as `#RRGGBB`.'
            string :email_heading_color, nullable: true,
                                         description: 'Customer email headings and emphasized text, as `#RRGGBB`.'
            string :email_font, nullable: true, example: 'inter',
                                description: 'Customer email font: `inter`, `system`, `helvetica`, `georgia`, `roboto`, `lato` or `merriweather`.'
            string :logo_signed_id, nullable: true,
                                    description: 'A `signed_id` from `files.upload()` for the store logo, or null to remove it.'
            string :mailer_logo_signed_id, nullable: true,
                                           description: 'A `signed_id` from `files.upload()` for the logo in transactional emails, or null to remove it.'
          end

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

          # Extensions' fields too: the store settings page saves the fields
          # plugins add to it with the rest of the form.
          def permitted_params
            params.permit(*declared_permitted_attributes, *Array(Spree::Store.additional_permitted_attributes))
          end
        end
      end
    end
  end
end
