module Spree
  module Api
    module V3
      module Seller
        module Orders
          # The notes on one of this seller's orders: the instructions the
          # buyer left, and the seller's own working note.
          #
          # A marketplace basket splits into one order per seller, so the
          # internal note on this row is the seller's alone — never the
          # operator's note about the whole sale.
          #
          # Singular, because an order has one set of notes: reading and
          # writing them is a resource rather than a verb on the order.
          class NotesController < BaseController
            # The notes are columns on the order, not a nested collection, so
            # there is no member record to fetch.
            skip_before_action :set_resource, raise: false

            # GET /api/v3/seller/orders/:order_id/notes
            def show
              render json: serialize_resource(@order)
            end

            # PATCH /api/v3/seller/orders/:order_id/notes
            #
            # Send only the note that changes: an absent key leaves the other
            # alone, while an empty string clears it.
            def update
              attributes = notes_params
              return render_validation_error(missing_notes_errors) if attributes.empty?

              if @order.update(attributes)
                render json: serialize_resource(@order.reload)
              else
                render_validation_error(@order.errors)
              end
            end

            protected

            def model_class
              Spree::Order
            end

            # The whole order, so a client refreshing a note gets the same
            # shape it renders the page from.
            def serializer_class
              Spree.api.seller_order_serializer
            end

            def read_actions
              %w[show]
            end

            private

            # The rich-text note is written through `internal_note`, which the
            # model sanitizes — the `_html` reader is its round-trip partner,
            # never a write.
            def notes_params
              permitted = params.permit(:customer_note, :internal_note)

              {}.tap do |attributes|
                attributes[:customer_note] = permitted[:customer_note] if params.key?(:customer_note)
                attributes[:internal_note] = permitted[:internal_note] if params.key?(:internal_note)
              end
            end

            # A request naming neither note has asked for nothing; saying so
            # beats a 200 that changed nothing.
            def missing_notes_errors
              ActiveModel::Errors.new(@order).tap do |errors|
                errors.add(:base, :blank, message: 'customer_note or internal_note is required')
              end
            end
          end
        end
      end
    end
  end
end
