module Spree
  module Api
    module V3
      # Serving a label file, shared by every surface that offers one — the
      # operator's, the seller's and the customer's return download.
      #
      # The bytes are streamed rather than redirected to storage, so the
      # credentials that reached the action are what protects the file. The
      # one exception is a label whose file is still being fetched from the
      # carrier: until it lands, the carrier's own copy stands in.
      #
      # Deliberately carries no scope of its own — the caller has already
      # fetched and authorized the label.
      module StreamsShippingLabel
        extend ActiveSupport::Concern

        # @param shipping_label [Spree::ShippingLabel]
        # @yield when there is nothing to serve, so each surface answers in
        #   its own vocabulary (a 404 for a customer, a 422 for staff)
        def stream_shipping_label(shipping_label, &on_missing)
          if shipping_label.file.attached?
            send_data(
              shipping_label.file.download,
              filename: shipping_label.download_filename,
              type: shipping_label.file.content_type || 'application/octet-stream',
              disposition: 'attachment'
            )
          elsif shipping_label.file_pending?
            redirect_to shipping_label.file_url, allow_other_host: true
          else
            on_missing.call
          end
        end
      end
    end
  end
end
