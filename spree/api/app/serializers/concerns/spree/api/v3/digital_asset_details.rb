module Spree
  module Api
    module V3
      # What a panel shows about a downloadable file: its size, the limits
      # that apply to it, and a short-lived link to check what was uploaded.
      # Shared by the operator's and a seller's serializer, so both panels
      # read the same fields.
      module DigitalAssetDetails
        extend ActiveSupport::Concern

        included do
          typelize byte_size: [:number, nullable: true],
                   authorized_clicks: [:number, nullable: true],
                   authorized_days: [:number, nullable: true],
                   effective_authorized_clicks: :number,
                   effective_authorized_days: :number,
                   provider_type: [:string, nullable: true, comment: 'Digital asset provider; null is an uploaded file. Built-in: file. Extensions may register more.'],
                   provider_name: [:string, comment: 'Digital asset provider name. Built-in: File. Extensions may register more.'],
                   download_url: [:string, nullable: true]

          attributes :authorized_clicks, :authorized_days, :byte_size
          attributes created_at: :iso8601, updated_at: :iso8601

          api_type_attributes :provider_type

          # Human-readable source for the listing. Blank provider_type is the
          # uploaded-file default, so this reads "File" there.
          attribute :provider_name do |digital_asset|
            digital_asset.provider_class.provider_name
          end

          # Lets a merchant check what they actually uploaded. Short-lived and
          # panel-only: this is the file itself, not a customer's download
          # grant, so it carries no counter and spends nobody's allowance.
          # Nil for a provider-backed asset (no file to preview) and outside a
          # request (the Disk service needs a host only a controller supplies).
          attribute :download_url do |digital_asset, params|
            next nil unless digital_asset.downloadable?

            store = params&.dig(:store) || Spree::Current.store || digital_asset.store
            begin
              digital_asset.download_url(expires_in: store.preferred_digital_asset_link_expire_time.seconds)
            rescue ArgumentError
              nil
            end
          end

          # The limits actually applied, after the store-settings fallback. The
          # request's store answers it; the asset's own store covers
          # serialization outside a request.
          attribute :effective_authorized_clicks do |digital_asset, params|
            store = params&.dig(:store) || Spree::Current.store || digital_asset.store
            digital_asset.effective_authorized_clicks(store)
          end

          attribute :effective_authorized_days do |digital_asset, params|
            store = params&.dig(:store) || Spree::Current.store || digital_asset.store
            digital_asset.effective_authorized_days(store)
          end
        end
      end
    end
  end
end
