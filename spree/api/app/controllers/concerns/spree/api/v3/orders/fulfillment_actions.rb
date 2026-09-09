module Spree
  module Api
    module V3
      module Orders
        # Dispatching what is owed on an order: shipping a parcel, cancelling
        # one, and splitting goods that leave separately.
        #
        # Shared by the operator's branch and the seller's, which run the same
        # workflows. What differs is only *whose records a payload may name*,
        # and that stays in the including controller: this concern never
        # fetches an order, a variant or a stock location. `@order` and
        # `@resource` arrive already fetched and authorized — through
        # `current_store` on one branch, `current_seller_orders` on the other
        # — and this code never learns which.
        module FulfillmentActions
          extend ActiveSupport::Concern

          # PATCH .../fulfillments/:id
          def update
            with_order_lock do
              result = Spree.fulfillment_update_workflow.call(
                fulfillment: @resource, fulfillment_attributes: update_attributes
              )

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_result_error(result)
              end
            end
          end

          # PATCH .../fulfillments/:id/fulfill
          #
          # Ships the parcel. `items` narrows it to part of what the
          # fulfillment holds, which splits the rest onto a new one.
          def fulfill
            with_order_lock do
              result = Spree.fulfillment_fulfill_workflow.call(
                fulfillment: @resource,
                items: items_for_fulfill,
                tracking: fulfill_params[:tracking],
                tracking_carrier: fulfill_params[:tracking_carrier],
                notify_customer: notify_customer?(fulfill_params[:notify_customer]),
                **fulfill_workflow_options
              )

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end
          end

          # PATCH .../fulfillments/:id/cancel
          #
          # Restocking and standing the carrier down happen in the workflow.
          def cancel
            with_order_lock do
              result = Spree.fulfillment_cancel_workflow.call(fulfillment: @resource)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end
          end

          # PATCH .../fulfillments/:id/split
          #
          # Moves part of what this parcel holds onto one of its own, for
          # goods leaving separately. Answers with every fulfillment on the
          # order, since splitting rewrites more than one.
          def split
            with_order_lock do
              changer = @resource.transfer_to_location(
                variant_for_split, params[:quantity].to_i, stock_location_for_split
              )

              if changer.run!
                render json: {
                  data: @order.reload.fulfillments.map { |fulfillment| serialize_resource(fulfillment) }
                }
              else
                render_validation_error(changer.errors)
              end
            end
          end

          protected

          def model_class
            Spree::Fulfillment
          end

          def parent_association
            :fulfillments
          end

          private

          def fulfill_params
            @fulfill_params ||= params.permit(*fulfill_permitted_keys)
          end

          def fulfill_permitted_keys
            [:tracking, :tracking_carrier, :notify_customer, { items: [:item_id, :quantity] }]
          end

          # Extra keywords the branch's own fulfil accepts — forcing past a
          # guard is the operator's call, so the seller adds nothing.
          def fulfill_workflow_options
            {}
          end

          # The workflow addresses what to ship by line item, and the lookup
          # runs through the order so an id from elsewhere cannot be shipped.
          def items_for_fulfill
            return if fulfill_params[:items].nil?

            fulfill_params[:items].map do |item|
              {
                line_item: @order.line_items.find_by_prefix_id!(item[:item_id]),
                quantity: Integer(item[:quantity].to_s, exception: false)
              }
            end
          end

          # Only an explicit false suppresses the email; an omitted flag keeps
          # sending it.
          def notify_customer?(value)
            !ActiveModel::Type::Boolean.new.cast(value).equal?(false)
          end

          # The attributes handed to the update workflow. The workflow assigns
          # ids raw, so a branch that must narrow one resolves it here first.
          def update_attributes
            permitted_params.to_h
          end

          # What may be split out of this parcel, and where the split half
          # ships from. Both are left to the including controller: they decide
          # whose catalogue and whose shelves are reachable.
          def variant_for_split
            raise NotImplementedError, "#{self.class} must implement #variant_for_split"
          end

          def stock_location_for_split
            raise NotImplementedError, "#{self.class} must implement #stock_location_for_split"
          end
        end
      end
    end
  end
end
