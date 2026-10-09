module Spree
  module Api
    module V3
      module Admin
        class StoreSerializer < V3::BaseSerializer
          typelize name: :string, url: :string, code: :string, api_url: :string,
                   default_currency: :string, default_locale: :string,
                   default_country_code: [:string, nullable: true],
                   supported_currencies: [:string, multi: true],
                   supported_locales: [:string, multi: true],
                   available_locales: [:string, multi: true],
                   logo_url: [:string, nullable: true],
                   mailer_logo_url: [:string, nullable: true],
                   mail_from_address: [:string, nullable: true],
                   customer_support_email: [:string, nullable: true],
                   new_order_notifications_email: [:string, nullable: true],
                   order_routing_strategy: [:string, comment: 'Order routing strategy. Built-in: rules. Extensions may register more.'],
                   payout_provider: [:string, nullable: true, comment: 'Payout provider; null uses the installation default. Built-in: system. Provider gems register more (e.g. stripe).'],
                   order_number_sequence_started: :boolean,
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     :name,
                     :code,
                     :default_currency,
                     :default_locale,
                     :default_country_code,
                     :mail_from_address,
                     :customer_support_email,
                     :new_order_notifications_email,
                     created_at: :iso8601, updated_at: :iso8601

          api_type_attributes :order_routing_strategy, :payout_provider

          preference_attributes Spree::Store,
                                :storefront_url, :send_consumer_transactional_emails, :email_accent_color,
                                :email_background_color, :email_card_color, :email_text_color, :email_heading_color,
                                :email_font, :admin_locale, :timezone, :weight_unit, :unit_system, :storefront_access,
                                :guest_checkout, :always_include_confirm_step, :company_field_enabled,
                                :address_requires_company, :address_requires_phone, :capture_method,
                                :track_inventory_levels, :stock_reservations_enabled, :low_stock_threshold,
                                :tax_using_ship_address, :track_price_history, :show_products_without_price,
                                :disable_sku_validation, :pricing_provider, :inventory_provider,
                                :pricing_provider_failure_policy, :inventory_provider_failure_policy,
                                :default_payouts_schedule_interval,
                                :auto_approve_sellers, :auto_approve_seller_products,
                                :send_seller_transactional_emails,
                                :document_number_format, :order_number_prefix, :order_number_suffix,
                                :order_number_sequence_start, :limit_digital_download_count,
                                :digital_asset_authorized_clicks, :limit_digital_download_days,
                                :digital_asset_authorized_days

          # Once the counter has issued a number the starting value no longer
          # applies, so the settings page can say that instead of accepting a
          # value that does nothing.
          attribute :order_number_sequence_started do |store|
            Spree::NumberSequence.started?(store: store)
          end

          typelize default_minimum_payout_amount: [:string, nullable: true]

          attribute :default_minimum_payout_amount do |store|
            Spree::Money::Rounding.format(store.preferred_default_minimum_payout_amount, store.default_currency, unit_price: true)
          end

          rate_attributes :default_commission_tax_rate

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
