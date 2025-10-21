require 'open-uri'

module Spree
  module Images
    class SaveFromUrlJob < ::Spree::BaseJob
      queue_as Spree.queues.images
      retry_on ActiveRecord::RecordInvalid, OpenURI::HTTPError, wait: :polynomially_longer, attempts: 2
      discard_on URI::InvalidURIError

      def perform(viewable_id, viewable_type, external_url, external_id = nil, position = nil)
        viewable = viewable_type.safe_constantize.find(viewable_id)

        Spree::Image.ensure_metafield_definition_exists!(Spree::Image::EXTERNAL_URL_METAFIELD_KEY)

        external_url = external_url.downcase.strip
        external_id = external_id.to_s.downcase.strip if external_id.present?

        image = find_or_initialize_image(viewable, external_url, external_id)

        image.set_default_values_for_import if image.new_record? && image.respond_to?(:set_default_values_for_import)

        return if image.skip_import?

        image.restore if image.respond_to?(:deleted?) && image.deleted?
        image.position = position if position.present?

        # don't re-download the image if it's already been downloaded
        # still trigger save! if position has changed
        image.save! and return if image_already_saved?(image, external_url)

        uri = URI.parse(external_url)
        unless %w[http https].include?(uri.scheme)
          raise URI::InvalidURIError, "Invalid URL scheme: #{uri.scheme}. Only http and https are allowed."
        end

        file = uri.open
        filename = File.basename(uri.path)

        image.attachment.attach(io: file, filename: filename)
        image.external_url = external_url
        image.external_id = external_id if external_id.present? && image.respond_to?(:external_id)
        image.save!
      rescue ActiveStorage::IntegrityError => e
        raise e unless Rails.env.test?
      end

      private

      def image_already_saved?(image, external_url)
        image.persisted? && image.attachment.attached? && image.external_url.present? && external_url == image.external_url
      end

      def image_scope(viewable)
        if Spree::Image.respond_to?(:with_deleted)
          viewable.images.with_deleted
        else
          viewable.images
        end
      end

      def find_or_initialize_image(viewable, external_url, external_id = nil)
        if external_id.present? && viewable.respond_to?(:external_id)
          image_scope(viewable).find_or_initialize_by(external_id: external_id)
        else
          image_scope(viewable).with_external_url(external_url).first || viewable.images.new
        end
      end
    end
  end
end
