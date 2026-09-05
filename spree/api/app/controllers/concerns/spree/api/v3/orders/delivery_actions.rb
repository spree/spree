module Spree
  module Api
    module V3
      module Orders
        # The consignments of one fulfillment — a parcel each, or a freight
        # PRO number covering several pallets.
        #
        # A delivery is born when a tracking number is attached, days before
        # anything arrives, so POST means "this went out as another
        # consignment"; arrival is a transition on an existing row.
        #
        # Shared by the operator's branch and the seller's. `@parent` (the
        # fulfillment) and `@resource` arrive already fetched and authorized,
        # so including this concern cannot widen what a caller reaches.
        module DeliveryActions
          extend ActiveSupport::Concern

          # POST .../deliveries
          def create
            authorize!(:create, Spree::Delivery)

            with_order_lock do
              # Every key is passed whether or not the request carried it, so
              # the service sees a missing tracking number as a blank one to
              # reject rather than a keyword it was never given.
              result = Spree.delivery_create_service.call(
                owner: @parent,
                **resource_permitted_attributes.index_with { |key| delivery_params[key] }
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_result_error(result)
              end
            end
          end

          # PATCH .../deliveries/:id — correcting the number, carrier or link.
          #
          # A corrected number is a different parcel as far as the carrier is
          # concerned: its journey starts over, and the carrier and link that
          # belonged to the old number go with it unless this request supplies
          # new ones. A consignment that started over may also have been the
          # one holding the fulfillment at delivered.
          def update
            with_order_lock do
              if @resource.update(@resource.correction_attributes(delivery_params.to_h))
                recalculate_fulfillment_delivery
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end
          end

          # DELETE .../deliveries/:id — 422 when a label minted it.
          def destroy
            with_order_lock do
              result = Spree.delivery_destroy_service.call(delivery: @resource)

              if result.success?
                head :no_content
              else
                render_result_error(result)
              end
            end
          end

          protected

          def model_class
            Spree::Delivery
          end

          def parent_association
            :deliveries
          end

          def collection_includes
            [:shipping_label]
          end

          def resource_permitted_attributes
            [:tracking_number, :carrier, :service, :tracking_url]
          end

          private

          def delivery_params
            @delivery_params ||= params.permit(*resource_permitted_attributes)
          end

          # Deliveries can hang off something other than a fulfillment, which
          # has no delivered state to roll up.
          def recalculate_fulfillment_delivery
            return unless @parent.is_a?(Spree::Fulfillment)

            Spree.fulfillment_recalculate_delivery_service.call(fulfillment: @parent)
          end
        end
      end
    end
  end
end
