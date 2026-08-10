# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class DigitalAssetSerializer < V3::DigitalAssetSerializer
          typelize byte_size: [:number, nullable: true],
                   authorized_clicks: [:number, nullable: true],
                   authorized_days: [:number, nullable: true],
                   effective_authorized_clicks: :number,
                   effective_authorized_days: :number

          attributes :authorized_clicks, :authorized_days, :byte_size
          attributes created_at: :iso8601, updated_at: :iso8601

          # The limits actually applied, after the store-settings fallback. The
          # request's store answers it — an admin request always carries one;
          # the asset's own store covers serialization outside a request.
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
