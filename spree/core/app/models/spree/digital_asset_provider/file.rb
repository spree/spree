module Spree
  module DigitalAssetProvider
    # The default provider: an uploaded file on private storage. Reproduces the
    # pre-wave-6 download behaviour — a short-lived signed storage URL the
    # customer is redirected to — now expressed through the provider seam.
    class File < Base
      def self.requires_attachment?
        true
      end

      def deliver(_digital_link, expires_in:)
        return unless digital_asset.attachment.attached?

        Spree::DigitalDelivery.new(
          redirect_url: digital_asset.attachment.url(expires_in: expires_in, disposition: :attachment)
        )
      end
    end
  end
end
