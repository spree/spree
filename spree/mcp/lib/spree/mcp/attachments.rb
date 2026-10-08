module Spree
  module Mcp
    # The files attached to records, offered as MCP resources.
    #
    # A buyer's purchase order, a shipping label, an uploaded import — the
    # paperwork a merchant would otherwise have to open themselves and
    # describe. Handed over as bytes rather than extracted text: the model
    # reading it already understands PDFs and images, so converting first
    # would lose the layout a document carries its meaning in.
    #
    # Which files exist here is {Spree.agent_attachments}' decision, and what
    # a caller may read is their record's own permission.
    module Attachments
      URI_SCHEME = 'spree+file'.freeze

      # Base64 adds a third again on the wire, and the body is read into
      # memory to send it. Beyond this a file is named and sized but not
      # inlined — the merchant opens it in the dashboard instead.
      MAX_INLINE_BYTES = 4_000_000

      # Per resource, newest first. A store accumulates these indefinitely and
      # every descriptor is sent on each listing.
      LISTING_LIMIT = 25

      class << self
        # @param context [Spree::AgentTools::Context]
        # @return [Array<Hash>] MCP resource descriptors
        def list(context)
          Spree.agent_attachments.flat_map do |entry|
            records_for(entry, context).filter_map do |record|
              file = entry.attached(record)
              descriptor(entry, record, file) if file
            end
          end
        end

        # @param context [Spree::AgentTools::Context]
        # @param uri [String]
        # @return [Array<Hash>, nil] contents, or nil when there is no such
        #   file this caller may read
        def read(context, uri)
          entry, record = resolve(context, uri)
          return if record.nil?

          file = entry.attached(record)
          return if file.nil?

          blob = file.blob
          return [too_large(uri, blob)] if blob.byte_size > MAX_INLINE_BYTES

          [{
            uri: uri,
            mimeType: blob.content_type.presence || 'application/octet-stream',
            blob: Base64.strict_encode64(file.download)
          }]
        end

        private

        def records_for(entry, context)
          entry.scope_for(context).limit(LISTING_LIMIT)
        rescue StandardError
          []
        end

        # `spree+file://orders/or_123` — the resource names which map entry
        # answers, so two resources carrying a file of the same name never
        # collide.
        def resolve(context, uri)
          resource, id = uri.to_s.delete_prefix("#{URI_SCHEME}://").split('/', 2)
          entry = Spree.agent_attachments.find(resource)
          return [nil, nil] if entry.nil? || id.blank?
          return [nil, nil] unless entry.readable_by?(context)

          # Found through the resource's own scope, so a record in another
          # store is indistinguishable from one that does not exist.
          [entry, entry.resource_entry.scope_for(context).find_by_prefix_id(id)]
        rescue StandardError
          [nil, nil]
        end

        def descriptor(entry, record, file)
          blob = file.blob

          {
            uri: "#{URI_SCHEME}://#{entry.resource}/#{record.prefixed_id}",
            name: blob.filename.to_s,
            title: title_for(entry, record, blob),
            description: "Attached #{blob.created_at.to_date.to_fs(:long)}",
            mimeType: blob.content_type.presence || 'application/octet-stream',
            size: blob.byte_size
          }
        end

        # "Purchase order for R1001", or just "Media file" where the record
        # has no name of its own beyond the file's — repeating the filename
        # in the title tells the model nothing twice.
        def title_for(entry, record, blob)
          owner = label_for(record)
          return entry.label if owner.blank? || owner == blob.filename.to_s

          "#{entry.label} for #{owner}"
        end

        # What a merchant calls the record this file hangs off.
        def label_for(record)
          %i[number name].each do |method|
            value = record.public_send(method) if record.respond_to?(method)
            return value.to_s if value.present?
          end

          nil
        end

        def too_large(uri, blob)
          {
            uri: uri,
            mimeType: 'text/plain',
            text: "This file is #{ActiveSupport::NumberHelper.number_to_human_size(blob.byte_size)}, " \
                  'too large to read here. Open it from the dashboard instead.'
          }
        end
      end
    end
  end
end
