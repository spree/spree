module Spree
  module Api
    module V3
      module Admin
        # A bought or uploaded carrier label. Admin-only by design: the cost is
        # what the merchant paid the carrier, and the ids are the provider's.
        # The file is streamed through +download_url+, never linked to storage.
        class ShippingLabelSerializer < V3::BaseSerializer
          typelize owner_id: :string,
                   owner_type: [:string, enum: Spree::ShippingLabel::OWNER_TYPES.map { |type| Spree::Base.polymorphic_api_type(type) }],
                   source: [:string, enum: Spree::ShippingLabel::SOURCES],
                   status: [:string, enum: Spree::ShippingLabel.statuses, enum_type_name: 'ShippingLabelStatus'],
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

          attributes :source, :status, :carrier, :carrier_name, :service, :tracking_number, :currency, :format,
                     :external_id, :metadata, refunded_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :owner

          attribute :owner_type do |shipping_label|
            Spree::Base.polymorphic_api_type(shipping_label.owner_type)
          end

          attributes cost: :string, display_cost: :string
          prefixed_id_attributes :integration

          # Whether the file is still being fetched from the carrier; the
          # download proxies the provider's copy meanwhile.
          attribute :file_pending, &:file_pending?

          # Our own endpoint rather than a storage URL: the controller streams
          # the bytes, so admin auth runs on every print.
          attribute :download_url do |shipping_label|
            next nil unless shipping_label.file.attached? || shipping_label.file_pending?

            helpers = Spree::Core::Engine.routes.url_helpers
            owner = shipping_label.owner
            # Both paths are nested under an order; a fulfillment still on a
            # cart has none, so there is nowhere to download it from yet.
            next nil if owner.order.nil?

            if owner.is_a?(Spree::Return)
              helpers.download_api_v3_admin_order_return_label_path(
                order_id: owner.order.prefixed_id, return_id: owner.prefixed_id, id: shipping_label.prefixed_id
              )
            else
              helpers.download_api_v3_admin_order_fulfillment_label_path(
                order_id: owner.order.prefixed_id, fulfillment_id: owner.prefixed_id, id: shipping_label.prefixed_id
              )
            end
          end
        end
      end
    end
  end
end
