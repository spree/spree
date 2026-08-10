module Spree
  module Api
    module V3
      module Admin
        class StoreSerializer < V3::BaseSerializer
          typelize name: :string, url: :string, code: :string, api_url: :string,
                   preferred_storefront_url: [:string, nullable: true],
                   default_currency: :string, default_locale: :string,
                   supported_currencies: [:string, multi: true],
                   supported_locales: [:string, multi: true],
                   available_locales: [:string, multi: true],
                   logo_url: [:string, nullable: true],
                   mailer_logo_url: [:string, nullable: true],
                   mail_from_address: [:string, nullable: true],
                   customer_support_email: [:string, nullable: true],
                   new_order_notifications_email: [:string, nullable: true],
                   preferred_send_consumer_transactional_emails: :boolean,
                   preferred_admin_locale: [:string, nullable: true],
                   preferred_timezone: :string,
                   preferred_weight_unit: :string,
                   preferred_default_package_weight: :number,
                   preferred_default_package_length: :number,
                   preferred_default_package_width: :number,
                   preferred_default_package_height: :number,
                   preferred_unit_system: :string,
                   preferred_storefront_access: :string,
                   preferred_guest_checkout: :boolean,
                   preferred_company_field_enabled: :boolean,
                   preferred_address_requires_company: :boolean,
                   preferred_address_requires_phone: :boolean,
                   preferred_capture_method: :string,
                   preferred_track_inventory_levels: :boolean,
                   preferred_stock_reservations_enabled: :boolean,
                   preferred_tax_using_ship_address: :boolean,
                   preferred_track_price_history: :boolean,
                   preferred_show_products_without_price: :boolean,
                   preferred_disable_sku_validation: :boolean,
                   preferred_order_routing_strategy: :string,
                   preferred_pricing_provider: :string,
                   preferred_inventory_provider: :string,
                   preferred_pricing_provider_failure_policy: :string,
                   preferred_inventory_provider_failure_policy: :string,
                   preferred_document_number_format: :string,
                   preferred_order_number_prefix: :string,
                   preferred_order_number_suffix: :string,
                   preferred_order_number_sequence_start: :number,
                   order_number_sequence_started: :boolean,
                   preferred_limit_digital_download_count: :boolean,
                   preferred_digital_asset_authorized_clicks: :number,
                   preferred_limit_digital_download_days: :boolean,
                   preferred_digital_asset_authorized_days: :number,
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     :name,
                     :code,
                     :preferred_storefront_url,
                     :default_currency,
                     :default_locale,
                     :mail_from_address,
                     :customer_support_email,
                     :new_order_notifications_email,
                     :preferred_send_consumer_transactional_emails,
                     :preferred_admin_locale,
                     :preferred_timezone,
                     :preferred_weight_unit,
                     :preferred_default_package_weight,
                     :preferred_default_package_length,
                     :preferred_default_package_width,
                     :preferred_default_package_height,
                     :preferred_unit_system,
                     :preferred_storefront_access,
                     :preferred_guest_checkout,
                     :preferred_company_field_enabled,
                     :preferred_address_requires_company,
                     :preferred_address_requires_phone,
                     :preferred_capture_method,
                     :preferred_track_inventory_levels,
                     :preferred_stock_reservations_enabled,
                     :preferred_tax_using_ship_address,
                     :preferred_track_price_history,
                     :preferred_show_products_without_price,
                     :preferred_disable_sku_validation,
                     :preferred_order_routing_strategy,
                     :preferred_pricing_provider,
                     :preferred_inventory_provider,
                     :preferred_pricing_provider_failure_policy,
                     :preferred_inventory_provider_failure_policy,
                     :preferred_document_number_format,
                     :preferred_order_number_prefix,
                     :preferred_order_number_suffix,
                     :preferred_order_number_sequence_start,
                     :preferred_limit_digital_download_count,
                     :preferred_digital_asset_authorized_clicks,
                     :preferred_limit_digital_download_days,
                     :preferred_digital_asset_authorized_days,
                     created_at: :iso8601, updated_at: :iso8601

          # Once the counter has issued a number the starting value no longer
          # applies, so the settings page can say that instead of accepting a
          # value that does nothing.
          attribute :order_number_sequence_started do |store|
            Spree::NumberSequence.started?(store: store)
          end

          attribute :url, &:storefront_url

          # The backend's own public URL — what a headless client sets as its
          # Store API endpoint (distinct from `url`, the storefront's URL).
          attribute :api_url, &:formatted_url

          # The Getting Started checklist in display order. Task names map to
          # frontend copy/components by convention.
          many :setup_tasks,
               resource: proc { Spree.api.admin_setup_task_serializer }

          attribute :supported_currencies do |store|
            store.supported_currencies_list.map(&:iso_code)
          end

          attribute :supported_locales, &:supported_locales_list

          # Canonical set of locales a merchant may translate content into,
          # independent of the store's currently-configured locales. Identical
          # for every store, so the locale pickers can offer the full list
          # rather than only locales already in use (avoids a chicken-and-egg
          # where a new locale can never be added). See `Spree::Locales::ALL`.
          attribute :available_locales do
            Spree::Locales::ALL
          end

          attribute :logo_url do |store|
            image_url_for(store.logo)
          end

          attribute :mailer_logo_url do |store|
            image_url_for(store.mailer_logo)
          end
        end
      end
    end
  end
end
