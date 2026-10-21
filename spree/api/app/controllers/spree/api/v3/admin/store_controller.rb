module Spree
  module Api
    module V3
      module Admin
        class StoreController < Admin::BaseController
          scoped_resource :settings

          request_params :store do |body|
            body.attribute :name, :string, example: 'My Store'
            body.attribute :admin_locale, :string, example: 'en'
            body.attribute :timezone, :string, example: 'Europe/Berlin'
            body.attribute :weight_unit, :weight_unit
            body.attribute :unit_system, :string, choices: Spree::Store::UNIT_SYSTEMS
            body.attribute :storefront_access, :string,
              choices: Spree::Channel::Gating::STOREFRONT_ACCESS,
              description: "The store-wide default for what anonymous visitors can see. Channels fall back to it when they don't set their own."
            body.attribute :storefront_url, :string,
              nullable: true,
              description: "The storefront's public URL, the base for links in customer emails. Saving it also completes the storefront setup task."
            body.attribute :guest_checkout, :boolean,
              description: 'The store-wide default for guest checkout. Channels fall back to it.'
            body.attribute :always_include_confirm_step, :boolean,
              description: 'Always show a confirmation step in checkout, even when no payment method requires one.'
            body.attribute :company_field_enabled, :boolean, description: 'Shows a company field on address forms.'
            body.attribute :address_requires_company, :boolean,
              description: 'Makes a company name mandatory on addresses.'
            body.attribute :address_requires_phone, :boolean,
              description: 'Makes a phone number mandatory on customer addresses.'
            body.attribute :capture_method, :string,
              choices: Spree::CaptureMethod::CAPTURE_METHODS,
              description: "The store-wide default for when a customer is charged rather than only authorized. A payment method's own setting wins when set."
            body.attribute :track_inventory_levels, :boolean,
              description: 'Counts on-hand quantities. Off means everything is treated as always available.'
            body.attribute :stock_reservations_enabled, :boolean,
              description: "Holds stock for shoppers while they check out, so the same item can't be sold twice."
            body.attribute :low_stock_threshold, :integer,
              description: 'On-hand units at or below which a tracked variant counts as low stock on the home screen; 0 turns the warning off.'
            body.attribute :tax_using_ship_address, :boolean,
              description: 'Calculates tax from the shipping address. When false, tax is calculated from the billing address.'
            body.attribute :track_price_history, :boolean,
              description: 'Records price changes for the EU Omnibus lowest-price-in-30-days display.'
            body.attribute :show_products_without_price, :boolean,
              description: "Whether products with no price in the shopper's currency still appear in listings."
            body.attribute :disable_sku_validation, :boolean,
              description: 'Lets more than one variant share the same SKU.'
            body.attribute :order_routing_strategy, :string,
              description: 'The store-wide order routing strategy shorthand. Channels fall back to it.'
            body.attribute :pricing_provider, :string,
              description: 'Where prices come from: a registered provider key, or `internal`.'
            body.attribute :inventory_provider, :string,
              description: 'Where stock levels come from: a registered provider key, or `internal`.'
            body.attribute :pricing_provider_failure_policy, :string,
              choices: Spree::ProviderFailurePolicy::VALUES,
              description: '`strict` refuses to price when the provider cannot answer; `fallback` uses the catalog.'
            body.attribute :inventory_provider_failure_policy, :string,
              choices: Spree::ProviderFailurePolicy::VALUES,
              description: '`fallback` sells on the local stock snapshot when the provider cannot answer; `strict` refuses.'
            body.attribute :payout_provider, :string,
              description: 'Blank means the built-in provider: the marketplace settles by hand.'
            body.attribute :default_payouts_schedule_interval, :string, choices: Spree::Seller::PAYOUT_INTERVALS
            body.attribute :default_minimum_payout_amount, :decimal,
              example: '50.00',
              description: "In the store's currency."
            body.attribute :auto_approve_sellers, :boolean,
              description: 'Admits a seller as soon as they finish onboarding, with no operator review.'
            body.attribute :auto_approve_seller_products, :boolean,
              description: 'Puts a seller product on sale the moment it is submitted, with no review.'
            body.attribute :send_seller_transactional_emails, :boolean,
              description: 'When false, transactional seller emails (approval, payouts and so on) are not sent.'
            body.attribute :default_commission_tax_rate, :decimal,
              example: '0.23',
              description: 'Tax charged on commission as a fraction (`"0.23"` is 23%), when neither the commission rate nor the tax provider names one.'
            body.attribute :document_number_format, :string,
              example: 'sequential',
              description: 'How document numbers are produced: `sequential` or `random`. Applies to every numbered document.'
            body.attribute :order_number_prefix, :string,
              example: 'R',
              description: 'Leads every order number. Uppercase letters, digits, dashes and # only.'
            body.attribute :order_number_suffix, :string,
              description: 'Ends every order number. Uppercase letters, digits, dashes and # only.'
            body.attribute :order_number_sequence_start, :integer,
              description: "The first sequential order number. Only applies before the store's first order."
            body.attribute :limit_digital_download_count, :boolean,
              description: 'Whether a digital download link stops working after a number of clicks.'
            body.attribute :digital_asset_authorized_clicks, :integer,
              description: 'How many clicks a download link allows, unless the file sets its own.'
            body.attribute :limit_digital_download_days, :boolean,
              description: 'Whether a digital download link expires after a number of days.'
            body.attribute :digital_asset_authorized_days, :integer,
              description: 'How many days a download link stays valid, unless the file sets its own.'
            body.attribute :mail_from_address, :string, description: 'Sender address of every transactional email.'
            body.attribute :customer_support_email, :string,
              nullable: true,
              description: 'Customer-facing reply-to address shown in the storefront and email footers.'
            body.attribute :new_order_notifications_email, :string,
              nullable: true,
              description: 'Recipient of "new order placed" staff notifications.'
            body.attribute :send_consumer_transactional_emails, :boolean,
              description: 'When false, transactional customer emails (order confirmation and so on) are not sent.'
            body.attribute :email_accent_color, :string,
              nullable: true,
              description: 'Customer email buttons and links, as `#RRGGBB`. Blank keeps the outlined buttons emails ship with.'
            body.attribute :email_background_color, :string,
              nullable: true,
              description: 'Customer email page background, as `#RRGGBB`.'
            body.attribute :email_card_color, :string,
              nullable: true,
              description: 'Customer email card behind the content, as `#RRGGBB`.'
            body.attribute :email_text_color, :string,
              nullable: true,
              description: 'Customer email body text, as `#RRGGBB`.'
            body.attribute :email_heading_color, :string,
              nullable: true,
              description: 'Customer email headings and emphasized text, as `#RRGGBB`.'
            body.attribute :email_font, :string,
              nullable: true,
              example: 'inter',
              description: 'Customer email font: `inter`, `system`, `helvetica`, `georgia`, `roboto`, `lato` or `merriweather`.'
            body.attribute :logo_signed_id, :string,
              nullable: true,
              description: 'A `signed_id` from `files.upload()` for the store logo, or null to remove it.'
            body.attribute :mailer_logo_signed_id, :string,
              nullable: true,
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
