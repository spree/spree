module Spree
  # Gives attachment slots their API write name, `<slot>_signed_id`
  # (docs/plans/6.0-uploads-and-file-ownership.md).
  #
  #   signed_id_attachments :logo, :mailer_logo
  #   store.update(logo_signed_id: upload.signed_id) # attaches
  #   store.update(logo_signed_id: nil)              # removes
  #
  # A declared slot also refuses a file stored with the other visibility:
  # attaching never moves a file between storage services, so a public upload
  # attached to a private slot would stay readable at a public URL.
  module SignedIdAttachments
    extend ActiveSupport::Concern

    included do
      class_attribute :signed_id_attachment_slots, instance_writer: false, default: []

      validate :signed_id_attachments_on_their_storage, if: -> { signed_id_attachment_slots.any? }
    end

    class_methods do
      # @param slots [Array<Symbol>] `has_one_attached` slot names
      # @return [void]
      def signed_id_attachments(*slots)
        self.signed_id_attachment_slots += slots

        slots.each do |slot|
          define_method(:"#{slot}_signed_id=") { |signed_id| public_send(:"#{slot}=", signed_id) }
        end
      end

      # The name the API reports +attribute+'s errors under: `logo_signed_id`
      # for the `logo` slot, so a client reads them back under the field it sent.
      #
      # @param attribute [Symbol, String]
      # @return [String, nil] nil when +attribute+ is not a declared slot
      def signed_id_attribute_for(attribute)
        "#{attribute}_signed_id" if signed_id_attachment_slots.include?(attribute.to_sym)
      end
    end

    private

    def signed_id_attachments_on_their_storage
      signed_id_attachment_slots.each do |slot|
        blob = attachment_changes[slot.to_s].try(:blob)
        expected_service = self.class.reflect_on_attachment(slot)&.options&.dig(:service_name)
        next if blob.nil? || expected_service.nil? || blob.service_name.to_s == expected_service.to_s

        visibility = expected_service.to_s == Spree.private_storage_service_name.to_s ? 'private' : 'public'
        errors.add(slot, :wrong_visibility, message: I18n.t('spree.upload_wrong_visibility', visibility: visibility))
      end
    end
  end
end
