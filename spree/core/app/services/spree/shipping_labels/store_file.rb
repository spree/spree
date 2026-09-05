require 'ssrf_filter'

module Spree
  module ShippingLabels
    # Fetches a purchased label from the provider's hosted URL into Spree's
    # own private storage, so the merchant can reprint after the carrier's
    # link has expired and a disconnected integration never breaks a
    # warehouse. Called right after purchase and retried by
    # Spree::ShippingLabels::StoreFileJob when that first fetch fails.
    class StoreFile
      prepend Spree::ServiceModule::Base

      READ_TIMEOUT = 30
      OPEN_TIMEOUT = 10
      # Everything a carrier CDN can fail with that is not a bug here: a
      # blocked or unresolvable address, a refused or slow connection, a bad
      # certificate.
      FETCH_ERRORS = [
        SsrfFilter::Error, SocketError, Timeout::Error, OpenSSL::SSL::SSLError,
        SystemCallError, Net::HTTPBadResponse, Net::ProtocolError, URI::InvalidURIError
      ].freeze

      # @param shipping_label [Spree::ShippingLabel]
      # @return [Spree::ServiceModule::Result] the label with its file attached
      def call(shipping_label:)
        return success(shipping_label) if shipping_label.file.attached?

        url = shipping_label.file_url
        if url.blank?
          shipping_label.errors.add(:file, :no_file_url, message: Spree.t('shipping_labels.errors.no_file_url'))
          return failure(shipping_label)
        end

        begin
          response = SsrfFilter.get(url, http_options: { read_timeout: READ_TIMEOUT, open_timeout: OPEN_TIMEOUT })
        rescue *FETCH_ERRORS => e
          # A carrier CDN that is down, slow or refuses the address is an
          # ordinary outcome here, not an exception the caller should handle:
          # the purchase behind it is already a fact, and the job retries.
          shipping_label.errors.add(:file, :file_fetch_failed, message: Spree.t('shipping_labels.errors.file_fetch_failed', status: e.message))
          return failure(shipping_label)
        end

        unless response.is_a?(Net::HTTPSuccess)
          shipping_label.errors.add(:file, :file_fetch_failed, message: Spree.t('shipping_labels.errors.file_fetch_failed', status: response.code))
          return failure(shipping_label)
        end

        attach(shipping_label, response.body, url)
        shipping_label.save ? success(shipping_label) : failure(shipping_label)
      end

      private

      def attach(shipping_label, body, url)
        extension = shipping_label.format.presence || File.extname(URI.parse(url).path).delete('.').presence || 'pdf'
        filename = shipping_label.download_filename
        filename = "#{filename}.#{extension}" if File.extname(filename).blank?
        # Assigned rather than attached: attaching to a persisted record
        # writes the blob before validation, and the bytes decide whether
        # this is a label at all.
        shipping_label.file = { io: StringIO.new(body), filename: filename }
      end
    end
  end
end
