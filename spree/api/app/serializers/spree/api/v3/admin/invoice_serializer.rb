module Spree
  module Api
    module V3
      module Admin
        # An invoice as staff and accountants see it: where it came from, who
        # uploaded it, whether the buyer has been sent it, and whether it may
        # still be deleted.
        class InvoiceSerializer < V3::InvoiceSerializer
          typelize source: [:string, enum: Spree::Invoice::SOURCES, enum_type_name: 'InvoiceSource'],
                   order_id: [:string, nullable: true],
                   seller_payout_id: [:string, nullable: true],
                   issuer_id: :string,
                   external_reference: [:string, nullable: true],
                   sent_at: [:string, nullable: true],
                   can_be_deleted: :boolean,
                   uploaded_by_id: [:string, nullable: true],
                   uploaded_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   metadata: 'Record<string, unknown> | null'

          attributes :source, :external_reference, :metadata,
                     sent_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :order, :seller_payout, :issuer

          actor_attributes :uploaded_by

          # Lets the panels hide a delete the model will refuse.
          attribute :can_be_deleted, &:can_be_deleted?

          one :order,
              resource: proc { Spree.api.admin_order_serializer },
              if: proc { expand?('order') }

          attribute :download_url do |invoice|
            next nil unless invoice.file.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_admin_invoice_path(id: invoice.prefixed_id)
          end
        end
      end
    end
  end
end
