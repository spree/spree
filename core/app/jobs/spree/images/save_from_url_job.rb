require 'open-uri'

module Spree
  module Images
    class SaveFromUrlJob < ::Spree::BaseJob
      queue_as Spree.queues.images
      retry_on ActiveRecord::RecordInvalid, OpenURI::HTTPError, URI::InvalidURIError, wait: :polynomially_longer, attempts: 2

      def perform(viewable_id, viewable_type, external_url, position = nil)
        viewable = viewable_type.safe_constantize.find(viewable_id)

        Spree::Image.ensure_metafield_definition_exists!(Spree::Image::EXTERNAL_URL_METAFIELD_KEY)

        external_url = external_url.downcase.strip

        image_scope = if Spree::Image.respond_to?(:with_deleted)
                        viewable.images.with_deleted
                      else
                        viewable.images
                      end

        image = image_scope.with_external_url(external_url).first || viewable.images.new

        image.restore if image.respond_to?(:deleted?) && image.deleted?
        image.position = position if position.present?

        # don't re-download the image if it's already been downloaded
        # still trigger save! if position has changed
        image.save! and return if image_already_saved?(image, external_url)

        uri = URI.parse(external_url)
        file = uri.open
        filename = uri.path.split('/').last

        image.attachment.attach(io: file, filename: filename)
        image.external_url = external_url
        image.save!
      end

      private

      def image_already_saved?(image, external_url)
        image.persisted? && image.attachment.attached? && image.external_url.present? && external_url == image.external_url
      end
    end
  end
end
