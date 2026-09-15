module Spree
  module Api
    module V3
      module Admin
        # The deliveries nested under a purchase order or a transfer. Listing
        # and showing come from the base controller; recording one runs the
        # document's receive workflow, which the including controller names
        # along with the keyword it takes the document under.
        #
        # Every line a payload names is resolved through the document itself,
        # so a line from another order or transfer cannot be received here.
        module StockReceiptActions
          extend ActiveSupport::Concern
          include Spree::Api::V3::ItemsPayload

          included do
            before_action :authorize_parent_access!
          end

          protected

          def model_class
            Spree::StockReceipt
          end

          def serializer_class
            Spree.api.admin_stock_receipt_serializer
          end

          def parent_association
            :stock_receipts
          end

          def scope
            @parent.stock_receipts
          end

          def collection_includes
            [items: :line]
          end

          def resource_permitted_attributes
            [:received_at, :reference, :notes]
          end

          def create_workflow_arguments
            {
              receivable_keyword => @parent,
              items: items_for_receipt,
              received_at: params[:received_at],
              reference: params[:reference],
              notes: params[:notes],
              received_by: try_spree_current_user
            }
          end

          # What this delivery brought, per line. An omitted `items` means
          # "everything still outstanding arrived intact"; an explicit list —
          # even an empty one — is what the dock counted, and nothing more.
          #
          # @return [Array<Hash>, nil]
          def items_for_receipt
            sent = items_payload(%i[id quantity_accepted quantity_rejected rejection_reason notes])
            return nil if sent.nil?

            sent.map do |item|
              {
                item: @parent.items.find_by_prefix_id!(item[:id]),
                quantity_accepted: item[:quantity_accepted],
                quantity_rejected: item[:quantity_rejected],
                rejection_reason: item[:rejection_reason],
                notes: item[:notes]
              }
            end
          end

          # Reading receipts needs only to see the document; booking one is a
          # change to it.
          def authorize_parent_access!
            authorize_parent!(@parent)
          end
        end
      end
    end
  end
end
