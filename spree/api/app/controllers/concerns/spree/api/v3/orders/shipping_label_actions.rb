module Spree
  module Api
    module V3
      module Orders
        # The postage on a parcel: recording a label, printing it back, and
        # removing one that was uploaded by mistake.
        #
        # Shared by the operator's branch and the seller's. Buying a label is
        # NOT here: it needs a carrier account, which is the operator's, so
        # that action lives on the admin controller alone.
        #
        # `@parent` (the label's owner) and `@resource` arrive already fetched
        # and authorized, so including this concern cannot widen what a caller
        # reaches.
        module ShippingLabelActions
          extend ActiveSupport::Concern

          included do
            include ActiveStorage::SetCurrent
            include Spree::Api::V3::StreamsShippingLabel

            rescue_from ActiveSupport::MessageVerifier::InvalidSignature,
                        with: :render_invalid_signature
          end

          # GET .../labels/:id/download
          #
          # Streamed rather than redirected to storage, so the credentials
          # that reached the action are what protects the file.
          def download
            stream_shipping_label(@resource) do
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('shipping_labels.errors.no_file_url'),
                status: :unprocessable_content
              )
            end
          end

          # DELETE .../labels/:id
          #
          # Only an uploaded label: a purchased one has postage to refund, so
          # it goes through the refund action instead.
          def destroy
            unless @resource.uploaded?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: Spree.t('shipping_labels.errors.purchased_not_deletable'),
                status: :unprocessable_content
              )
            end

            with_order_lock do
              # The consignment goes with the label only while the parcel
              # never moved — a journey that happened is a fact. Once it has,
              # the delivery stays and is simply unlinked, so a wrong PDF can
              # still be removed and replaced.
              @resource.release_unmoved_delivery
              @resource.destroy!
              head :no_content
            end
          end

          protected

          def model_class
            Spree::ShippingLabel
          end

          def parent_association
            :shipping_labels
          end

          def collection_includes
            [{ file_attachment: :blob }]
          end

          # Downloading is reading, so it must not demand write access to the
          # parcel the label belongs to.
          def read_actions
            %w[index show download]
          end

          private

          def label_permitted_keys
            [:file, :tracking_number, :carrier, :service,
             :cost, :currency, :file_format, :tracking_url]
          end

          def label_params
            @label_params ||= params.permit(*label_permitted_keys)
          end

          # Records a label bought outside Spree.
          #
          # Every key is passed whether or not the request carried it, so the
          # workflow sees a missing tracking number as a blank one to reject
          # rather than a keyword it was never given.
          def record_uploaded_label
            with_order_lock do
              result = Spree.shipping_label_record_workflow.call(
                owner: @parent,
                **label_permitted_keys.index_with { |key| label_params[key] }
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_result_error(result)
              end
            end
          end

          # A tampered or expired direct-upload signature is a bad parameter,
          # not a server fault.
          def render_invalid_signature
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:parameter_invalid],
              message: Spree.t('shipping_labels.errors.file_required'),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
