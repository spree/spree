require 'open-uri'
require 'openssl'
require 'ssrf_filter'
require 'tempfile'

module Spree
  module Images
    class SaveFromUrlJob < ::Spree::BaseJob
      queue_as Spree.queues.images
      retry_on ActiveRecord::RecordInvalid, wait: :polynomially_longer, attempts: Spree::Config.images_save_from_url_job_attempts.to_i
      discard_on URI::InvalidURIError
      discard_on SsrfFilter::Error

      # The system a bare external id is filed under when the caller names
      # none. A DAM or PIM feeding media through this job should pass
      # `{ system:, external_id: }` and name itself.
      DEFAULT_EXTERNAL_SYSTEM = 'import'.freeze

      # @param external_id [String, Hash, Array, nil] the identities the source
      #   systems know this media by — a bare id, a `{ system:, external_id: }`
      #   hash, or a list of them when several systems name the same asset.
      #   Recorded as Spree::ExternalReferences on the media, and used to find
      #   the row again on the next run so a feed never re-imports.
      # @param position [Integer, nil] the media's position in the gallery
      # @param link_variant_id [Integer, nil] links the product-level media to
      #   this variant once saved
      # @return [void]
      def perform(viewable_id, viewable_type, external_url, external_id = nil, position = nil, link_variant_id = nil)
        viewable = viewable_type.safe_constantize.find(viewable_id)

        Spree::Media.ensure_custom_field_definition_exists!(Spree::Media::EXTERNAL_URL_CUSTOM_FIELD_KEY)

        external_url = external_url.strip
        references = external_references_from(external_id)

        image = find_or_initialize_image(viewable, external_url, references)

        image.set_default_values_for_import if image.new_record? && image.respond_to?(:set_default_values_for_import)

        return if image.skip_import?

        image.restore if image.respond_to?(:deleted?) && image.deleted?
        image.position = position if position.present?

        # don't re-download the image if it's already been downloaded
        # still trigger save! if position has changed
        if image_already_saved?(image, external_url)
          image.save!
          record_external_references(image, references)
          link_to_variant(image, link_variant_id)
          return
        end

        download_and_attach_image(external_url, image)
        record_external_references(image, references)
        link_to_variant(image, link_variant_id)
      rescue ActiveStorage::IntegrityError => e
        raise e unless Rails.env.test?
      end

      private

      def download_and_attach_image(external_url, image)
        max_size = Spree::Config.max_image_download_size

        response = SsrfFilter.get(
          external_url,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept' => 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'Accept-Language' => 'en-US,en;q=0.9',
            'Accept-Encoding' => 'gzip, deflate, br',
            'Cache-Control' => 'no-cache',
            'Pragma' => 'no-cache'
          },
          http_options: {
            read_timeout: 60,
            open_timeout: 30
          }
        )

        body = response.body
        if body.bytesize > max_size
          raise StandardError, "Image file size exceeds the maximum allowed size of #{max_size} bytes"
        end

        uri = URI.parse(external_url)
        filename = File.basename(uri.path)
        tempfile = Tempfile.new(['spree_image', File.extname(uri.path)], binmode: true)

        begin
          tempfile.write(body)
          tempfile.rewind

          image.attachment.attach(io: tempfile, filename: filename)
          image.external_url = external_url
          image.save!
        ensure
          tempfile.close
          tempfile.unlink
        end
      end

      def image_already_saved?(image, external_url)
        image.persisted? && image.attachment.attached? && image.external_url.present? && external_url == image.external_url
      end

      # `Product#images` delegates to the default variant — use `Product#media`
      # so 5.5 product-level uploads don't get re-pinned to that variant.
      def viewable_assets(viewable)
        viewable.is_a?(Spree::Product) ? viewable.media : viewable.images
      end

      def image_scope(viewable)
        scope = viewable_assets(viewable)
        scope.respond_to?(:with_deleted) ? scope.with_deleted : scope
      end

      # An identity from the source system wins over the URL: a DAM may move
      # the file and keep the id, and matching on the URL would then import a
      # second copy.
      def find_or_initialize_image(viewable, external_url, references = [])
        Array(references).each do |reference|
          existing = image_scope(viewable).with_external_id(reference[:system], reference[:external_id]).take
          return existing if existing.present?
        end

        image_scope(viewable).with_external_url(external_url).first || viewable_assets(viewable).new
      end

      # Normalises the caller's external ids — a bare string, a
      # `{ system:, external_id: }` hash, or a list of either — into one shape.
      def external_references_from(external_id)
        return [] if external_id.blank?

        entries = external_id.is_a?(Array) ? external_id : [external_id]
        entries.filter_map do |entry|
          if entry.is_a?(Hash)
            hash = entry.to_h.symbolize_keys
            next if hash[:external_id].blank?

            { system: hash[:system].presence || DEFAULT_EXTERNAL_SYSTEM, external_id: hash[:external_id].to_s.strip }
          elsif entry.present?
            { system: DEFAULT_EXTERNAL_SYSTEM, external_id: entry.to_s.strip }
          end
        end
      end

      def record_external_references(image, references)
        return unless image.persisted?

        Array(references).each { |reference| image.set_external_id(reference[:system], reference[:external_id]) }
      end

      def link_to_variant(image, variant_id)
        return if variant_id.blank?
        return unless image.persisted? && image.viewable_type == 'Spree::Product'

        Spree::VariantMedia.find_or_create_by(variant_id: variant_id, media_id: image.id)
      end
    end
  end
end
