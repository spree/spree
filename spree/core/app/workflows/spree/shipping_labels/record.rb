module Spree
  module ShippingLabels
    # Records a label the merchant bought elsewhere — postage from a carrier
    # site, a 3PL's PDF — so the parcel still has its file, its tracking
    # number and what it cost, with no carrier integration involved.
    #
    # The uploaded label mints its delivery like a purchased one; what it
    # cannot do is be refunded through Spree, so deleting it is the way out.
    class Record < Spree::Workflow
      hooks :validate, :after_record

      # The label that was recorded, readable by hook handlers.
      attr_reader :shipping_label

      # @param owner [Spree::Fulfillment, Spree::Return]
      # @param file [ActionDispatch::Http::UploadedFile, String] the file, or a signed blob id from a direct upload
      # @param tracking_number [String] the number printed on the label
      # @param carrier [String, nil] free text; detected from the number when omitted
      # @param service [String, nil]
      # @param cost [Numeric, nil] what the merchant paid; 0 when unknown
      # @param currency [String, nil]
      # @param file_format [String, nil] pdf | png | zpl; taken from the file when omitted
      # @param tracking_url [String, nil]
      # @return [Spree::ServiceModule::Result] the shipping label on success
      def perform(owner:, file:, tracking_number:, carrier: nil, service: nil, cost: nil, currency: nil, file_format: nil, tracking_url: nil)
        super

        run_hooks :validate

        step :ensure_recordable

        ApplicationRecord.transaction do
          step :record_label
          step :record_delivery
        end

        run_hooks :after_record
        success(shipping_label.reload)
      end

      private

      def ensure_recordable
        failure(owner, Spree.t('shipping_labels.errors.already_purchased')) if owner.shipping_labels.active.exists?
        failure(owner, Spree.t('shipping_labels.errors.tracking_number_required')) if tracking_number.blank?
        failure(owner, Spree.t('shipping_labels.errors.file_required')) if file.blank?

        case owner
        when Spree::Fulfillment
          failure(owner, Spree.t('fulfillments.errors.cannot_purchase_label')) if owner.canceled? || owner.delivered?
        when Spree::Return
          failure(owner, Spree.t('shipping_labels.errors.return_closed')) if owner.received? || owner.refunded? || owner.canceled?
        end
      end

      def record_label
        @shipping_label = owner.shipping_labels.new(
          store: owner.store,
          source: 'uploaded',
          status: 'purchased',
          carrier: carrier,
          service: service,
          tracking_number: tracking_number,
          cost: cost || 0,
          currency: currency.presence || owner.store.default_currency,
          file: file
        )
        @shipping_label.format = file_format.presence || format_from_file
        failure(@shipping_label) unless @shipping_label.save
      end

      # A direct-upload blob carries the type the client declared, which the
      # attachment validator re-decides from the bytes; either way the
      # extension is the merchant-visible answer, so it wins when it names a
      # format Spree knows.
      def format_from_file
        blob = @shipping_label.file.blob
        extension = File.extname(blob&.filename.to_s).delete('.').downcase
        return extension if Spree::ShippingLabel::FORMATS.include?(extension)

        case blob&.content_type.to_s
        when 'image/png' then 'png'
        when 'text/plain', 'application/zpl' then 'zpl'
        else 'pdf'
        end
      end

      def record_delivery
        existing = owner.deliveries.find_by(tracking_number: shipping_label.tracking_number)

        if existing
          existing.update!(shipping_label: shipping_label, carrier: carrier.presence || existing.carrier)
          return
        end

        result = Spree.delivery_create_service.call(
          owner: owner,
          tracking_number: shipping_label.tracking_number,
          carrier: carrier,
          service: service,
          tracking_url: tracking_url,
          shipping_label: shipping_label
        )
        failure(shipping_label, result.error.to_s) if result.failure?
      end
    end
  end
end
