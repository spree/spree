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

      # The file could not be fetched for a reason on the other end of the
      # wire: the host refused, reset or timed out the connection, its name did
      # not resolve, its certificate was bad, or it answered with an error
      # status (a 404, a 500, a rate limit). A host that is down now may be
      # back in a minute, so the fetch is retried; once the attempts run out
      # the media is simply not imported, as with a blocked address, rather
      # than raised as an error nobody can fix.
      class FetchFailed < StandardError; end

      # What the remote host can fail with while it is being fetched. Only the
      # fetch itself is guarded: the same classes raised while the download is
      # written to disk or attached (a full disk is an Errno too) are this
      # server's problem and propagate.
      #
      # SsrfFilter::UnresolvedHostname is an SsrfFilter::Error, but it means
      # the name did not resolve right now, not that it points somewhere
      # forbidden, so it is retried rather than discarded with the rest.
      FETCH_ERRORS = [
        SocketError, Timeout::Error, OpenSSL::SSL::SSLError, SystemCallError, EOFError,
        Net::HTTPBadResponse, Net::ProtocolError, SsrfFilter::UnresolvedHostname
      ].freeze

      retry_on(FetchFailed, wait: :polynomially_longer, attempts: Spree::Config.images_save_from_url_job_attempts.to_i) do |job, error|
        Rails.logger.warn(
          "[Spree::Images::SaveFromUrlJob] Gave up fetching #{job.arguments[2].to_s.strip}: #{error.message}"
        )
      end

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

        # The viewable's own store, not the current one: a job runs outside a
        # request, where `Spree::Current.store` answers with the default store
        # and would file every store's external-url definition on that one.
        Spree::Media.ensure_custom_field_definition_exists!(
          Spree::Media::EXTERNAL_URL_CUSTOM_FIELD_KEY, store: store_for(viewable)
        )

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

      # Mirrors how Spree::Media picks its own store: the viewable's, or its
      # product's for a variant.
      #
      # @return [Spree::Store]
      def store_for(viewable)
        viewable.try(:store) || viewable.try(:product)&.store || Spree::Store.default
      end

      def download_and_attach_image(external_url, image)
        max_size = Spree::Config.max_image_download_size
        streamed_body = nil

        response = fetch(external_url) do |fetched|
          # Every hop calls back, redirects included; their bodies are not the
          # file, but are drained here within the limit, since Net::HTTP would
          # otherwise read one whole into memory. An error status is refused
          # before its body is read, so a large error page is not mistaken for
          # an oversized image.
          next read_within(fetched, max_size, keep: false) if redirect?(fetched)

          raise_fetch_failed(external_url, fetched) unless success?(fetched)

          streamed_body = read_within(fetched, max_size)
        end

        # A fetch that did not stream (a test double, say) is checked here,
        # then read whole and held to the same limit.
        raise_fetch_failed(external_url, response) unless success?(response)

        body = streamed_body || response.body
        raise_too_large(max_size) if body.bytesize > max_size

        uri = URI.parse(external_url)
        filename = File.basename(uri.path)
        tempfile = Tempfile.new(['spree_image', File.extname(uri.path)], binmode: true)

        begin
          tempfile.write(body)
          tempfile.rewind

          image.attachment.attach(io: tempfile, filename: filename)
          # Saved first so a non-image file fails validation here, rather than
          # as a custom field with no owner; together, so a failed URL leaves
          # no image behind for the retry to duplicate.
          image.transaction do
            image.save!
            image.external_url = external_url
          end
        ensure
          tempfile.close
          tempfile.unlink
        end
      end

      # Fetches the URL through the SSRF filter, turning anything the remote
      # end fails with into FetchFailed so it is retried. Addresses the filter
      # blocks still raise their own SsrfFilter::Error and are discarded.
      def fetch(external_url, &)
        SsrfFilter.get(
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
          },
          &
        )
      rescue *FETCH_ERRORS => e
        raise FetchFailed, "#{e.class}: #{e.message}"
      end

      def success?(response)
        response.code.to_s.start_with?('2')
      end

      def redirect?(response)
        response.code.to_s.start_with?('3')
      end

      def raise_fetch_failed(external_url, response)
        raise FetchFailed, "#{external_url} responded with HTTP #{response.code}"
      end

      # Reads the body as it arrives and stops at the limit, so an oversized
      # or endless response is refused mid-stream rather than held in memory
      # first; a declared length over the limit is refused before any of it.
      def read_within(response, max_size, keep: true)
        raise_too_large(max_size) if response['Content-Length'].to_i > max_size

        buffer = +''
        size = 0
        response.read_body do |chunk|
          size += chunk.bytesize
          raise_too_large(max_size) if size > max_size
          buffer << chunk if keep
        end
        buffer
      end

      def raise_too_large(max_size)
        raise StandardError, "Image file size exceeds the maximum allowed size of #{max_size} bytes"
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

      # Normalises the caller's external ids into the shared entry shape.
      # This job's own additions over {Spree::ExternalReference.normalize_references}
      # are the legacy bare-string form and a default system for entries that
      # name none — everything else parses identically to the API.
      def external_references_from(external_id)
        return [] if external_id.blank?

        entries = (external_id.is_a?(Array) ? external_id : [external_id]).map do |entry|
          if entry.is_a?(Hash)
            hash = entry.to_h.symbolize_keys
            hash[:system].present? ? hash : hash.merge(system: DEFAULT_EXTERNAL_SYSTEM)
          elsif entry.present?
            { system: DEFAULT_EXTERNAL_SYSTEM, external_id: entry.to_s }
          end
        end

        Spree::ExternalReference.normalize_references(entries.compact)
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
