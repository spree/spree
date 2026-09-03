module Spree
  module Api
    module V3
      module Admin
        # A bought or uploaded carrier label. Admin-only by design: the cost is
        # what the merchant paid the carrier, and the ids are the provider's.
        # The file is streamed through +download_url+, never linked to storage.
        class ShippingLabelSerializer < V3::BaseSerializer
          typelize owner_id: :string,
                   owner_type: :string,
                   source: :string,
                   status: :string,
                   carrier: [:string, nullable: true],
                   carrier_name: [:string, nullable: true],
                   service: [:string, nullable: true],
                   tracking_number: [:string, nullable: true],
                   cost: :string,
                   currency: [:string, nullable: true],
                   display_cost: :string,
                   format: [:string, nullable: true],
                   external_id: [:string, nullable: true],
                   integration_id: [:string, nullable: true],
                   download_url: [:string, nullable: true],
                   file_pending: :boolean,
                   refunded_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :source, :status, :carrier, :service, :tracking_number, :currency, :format,
                     :external_id, :metadata, refunded_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          attribute :owner_id do |shipping_label|
            shipping_label.owner&.prefixed_id
          end

          attribute :owner_type do |shipping_label|
            shipping_label.owner_type == 'Spree::Return' ? 'return' : 'fulfillment'
          end

          attribute :carrier_name do |shipping_label|
            next if shipping_label.carrier.blank?

            Spree.tracking_carriers.dig(shipping_label.carrier, :name) || shipping_label.carrier
          end

          attribute :cost do |shipping_label|
            shipping_label.cost.to_s
          end

          attribute :display_cost do |shipping_label|
            shipping_label.display_cost.to_s
          end

          attribute :integration_id do |shipping_label|
            shipping_label.integration&.prefixed_id
          end

          # Whether the file is still being fetched from the carrier; the
          # download proxies the provider's copy meanwhile.
          attribute :file_pending do |shipping_label|
            shipping_label.file_pending?
          end

          # Our own endpoint rather than a storage URL: the controller streams
          # the bytes, so admin auth runs on every print.
          attribute :download_url do |shipping_label|
            next nil unless shipping_label.file.attached? || shipping_label.file_pending?

            helpers = Spree::Core::Engine.routes.url_helpers
            owner = shipping_label.owner
            if owner.is_a?(Spree::Return)
              helpers.download_api_v3_admin_order_return_label_path(
                order_id: owner.order.prefixed_id, return_id: owner.prefixed_id, id: shipping_label.prefixed_id
              )
            else
              helpers.download_api_v3_admin_order_fulfillment_label_path(
                order_id: owner.order&.prefixed_id, fulfillment_id: owner.prefixed_id, id: shipping_label.prefixed_id
              )
            end
          end
        end
      end
    end
  end
end
