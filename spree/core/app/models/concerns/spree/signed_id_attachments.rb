module Spree
  # Gives attachment slots their API write name, `<slot>_signed_id`
  # (docs/plans/6.0-uploads-and-file-ownership.md).
  #
  #   signed_id_attachments :logo, :mailer_logo
  #   store.update(logo_signed_id: upload.signed_id) # attaches
  #   store.update(logo_signed_id: nil)              # removes
  module SignedIdAttachments
    extend ActiveSupport::Concern

    class_methods do
      # @param slots [Array<Symbol>] `has_one_attached` slot names
      # @return [void]
      def signed_id_attachments(*slots)
        slots.each do |slot|
          define_method(:"#{slot}_signed_id=") { |signed_id| public_send(:"#{slot}=", signed_id) }
        end
      end
    end
  end
end
