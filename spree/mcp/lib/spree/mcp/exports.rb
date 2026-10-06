module Spree
  module Mcp
    # Finished exports, offered as MCP resources.
    #
    # A tool result has to fit the model's context; an export does not. A
    # catalog of ten thousand products is megabytes of CSV, which is why
    # `create_export` hands back an id rather than a file. Resources are the
    # protocol's answer to that: the client sees what exists, and fetches a
    # body only when it decides to.
    #
    # Reading one costs the same permission as reading the records it holds —
    # a customers export needs what a customer needs — so the file cannot
    # become a way around a scope the merchant withheld.
    module Exports
      URI_SCHEME = 'spree+export'.freeze

      # Beyond this the body is not something a model can usefully read, and
      # returning it would push out the conversation that asked for it. The
      # client is told the size, so it can offer the download instead.
      MAX_INLINE_BYTES = 1_000_000

      class << self
        # @param context [Spree::AgentTools::Context]
        # @return [Array<Hash>] MCP resource descriptors
        def list(context)
          readable(context).map { |export| descriptor(export) }
        end

        # @param context [Spree::AgentTools::Context]
        # @param uri [String]
        # @return [Array<Hash>, nil] contents, or nil when there is no such
        #   export this caller may read
        def read(context, uri)
          export = find(context, uri)
          return if export.nil?

          blob = export.attachment.blob
          return [too_large(uri, blob)] if blob.byte_size > MAX_INLINE_BYTES

          [{ uri: uri, mimeType: 'text/csv', text: export.attachment.download }]
        end

        private

        # Finished exports of this store that the caller's grant covers.
        #
        # `done?` rather than every export: an unfinished one has no file, and
        # naming it would have the model fetch something that cannot be read.
        def readable(context)
          context.store.exports.
            select { |export| export.done? && permitted?(context, export) }.
            sort_by(&:created_at).reverse
        end

        def find(context, uri)
          id = uri.to_s.delete_prefix("#{URI_SCHEME}://")
          export = context.store.exports.find_by_prefix_id(id)
          return unless export&.done? && permitted?(context, export)

          export
        rescue StandardError
          nil
        end

        # The scope the exported records themselves need. An export whose type
        # declares none is readable only by a credential holding everything,
        # which is how the Admin API treats an unmapped type.
        def permitted?(context, export)
          scope = export.class.try(:required_scope)
          return context.holds?('read_all') if scope.blank?

          context.holds?("read_#{scope}")
        end

        def descriptor(export)
          {
            uri: "#{URI_SCHEME}://#{export.prefixed_id}",
            name: export.attachment.blob.filename.to_s,
            title: "#{export.class.name.demodulize.underscore.humanize} export",
            description: "Generated #{export.created_at.to_date.to_fs(:long)}",
            mimeType: 'text/csv',
            size: export.attachment.blob.byte_size
          }
        end

        def too_large(uri, blob)
          {
            uri: uri,
            mimeType: 'text/plain',
            text: "This export is #{ActiveSupport::NumberHelper.number_to_human_size(blob.byte_size)}, " \
                  'too large to read here. Download it from the dashboard, or narrow the export with ' \
                  'filters and create a smaller one.'
          }
        end
      end
    end
  end
end
