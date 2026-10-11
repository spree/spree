module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Labels on a parcel the seller ships themselves.
          #
          # Recording, printing and deleting are shared with the operator's
          # branch through the concern. Buying and refunding are not: they
          # need the operator's carrier account, so a seller uploads a label
          # bought elsewhere and prints it back.
          #
          # Rooted at the order fetched through `current_seller_orders`, so a
          # fulfillment on somebody else's order reads as missing.
          class LabelsController < BaseController
            include Spree::Api::V3::Orders::ShippingLabelActions

            # The permit list itself lives in ShippingLabelActions, shared with
            # the operator's branch; this declaration documents it.
            request_params :shipping_label do |body|
              body.attribute :file_signed_id, :string,
                required: true,
                description: 'A `signed_id` from `files.upload()`.'
              body.attribute :tracking_number, :string,
                required: true,
                description: 'The number printed on the label.'
              body.attribute :carrier, :string,
                description: "Free text; a forwarder's name is as valid as a carrier slug. Detected from the number when omitted."
              body.attribute :service, :string, description: 'Carrier service the label was bought at.'
              body.attribute :cost, :decimal,
                description: "What the seller paid the carrier. Accounting data only; it never touches the order's shipping charge."
              body.attribute :currency, :currency, description: 'Currency of the cost.'
              body.attribute :file_format, :string,
                choices: %w[pdf png zpl],
                description: 'Taken from the file when omitted.'
              body.attribute :tracking_url, :string, description: 'Tracking page for the consignment the label mints.'
            end

            before_action :set_resource, only: [:show, :download, :destroy]

            # POST .../labels
            #
            # Records an uploaded label; a request without a file is refused,
            # since purchase is the operator's.
            def create
              authorize!(:create, Spree::ShippingLabel)

              if label_params[:file_signed_id].blank?
                return render_error(
                  code: ERROR_CODES[:validation_error],
                  message: I18n.t('spree.shipping_labels.errors.file_required'),
                  status: :unprocessable_content
                )
              end

              record_uploaded_label
            end

            protected

            def serializer_class
              Spree.api.seller_shipping_label_serializer
            end

            # The labels and consignments hang off the fulfillment, not the
            # order, so the parent is narrowed one step past the base's.
            def set_parent
              super
              @parent = @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
            end
          end
        end
      end
    end
  end
end
