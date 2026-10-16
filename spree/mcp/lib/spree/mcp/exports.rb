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

      # Set by what a model can read, not by what storage can hold. A CSV is
      # text, so this is roughly 50,000 tokens — a large but survivable share
      # of a context window. Beyond it the client is told the size and given
      # the dashboard link.
      MAX_INLINE_BYTES = 200_000

      # Exports whose rows carry a bearer instrument — a code that spends
      # money for whoever reads it. The merchant downloads these from the
      # dashboard; handing one to a model puts live codes in a third party's
      # chat history, which cannot be undone.
      #
      # `Spree::GiftCard` is already kept out of the resource map and out of
      # any serialized order for the same reason. An export must not be the
      # way around that. The list lives with the tool that creates them, so
      # refusing to make one and refusing to read one cannot disagree.

      class << self
        # @param context [Spree::AgentTools::Context]
        # @return [Array<Hash>] MCP resource descriptors
        def list(context)
          response = dispatch(context, :get, '/api/v3/admin/exports', params: { limit: 50 })
          return [] unless response.success?

          Array(response.data).
            select { |export| export['done'] && export['byte_size'].to_i.positive? }.
            map { |export| descriptor(export) }
        end

        # @param context [Spree::AgentTools::Context]
        # @param uri [String]
        # @return [Array<Hash>, nil] contents, or nil when there is no such
        #   export this caller may read
        def read(context, uri)
          id = uri.to_s.delete_prefix("#{URI_SCHEME}://")
          return if id.blank?

          # The endpoint answers 404 for an export of another store and for
          # one this credential's scopes do not cover, so there is no second
          # permission check here.
          export = dispatch(context, :get, "/api/v3/admin/exports/#{id}")
          return unless export.success?

          record = export.data.to_h
          return unless record['done']

          return [withheld(uri)] if bearer_export?(record['type'])

          size = record['byte_size'].to_i
          return [too_large(uri, size)] if size > MAX_INLINE_BYTES

          contents(context, uri, id)
        end

        private

        def contents(context, uri, id)
          file = dispatch(context, :get, "/api/v3/admin/exports/#{id}/download")
          return [{ uri: uri, mimeType: 'text/plain', text: file.error_message }] unless file.success?

          [{ uri: uri, mimeType: 'text/csv', text: file.content }]
        end

        def dispatch(context, method, path, params: {})
          Spree::AgentTools::ApiDispatch.new(context).call(method: method, path: path, params: params)
        end

        def descriptor(export)
          {
            uri: "#{URI_SCHEME}://#{export['id']}",
            name: export['filename'].to_s,
            title: "#{export['type'].to_s.tr('_', ' ').humanize} export".strip,
            description: "Generated #{Date.parse(export['created_at'].to_s).to_fs(:long)}",
            mimeType: 'text/csv',
            size: export['byte_size']
          }
        rescue Date::Error
          { uri: "#{URI_SCHEME}://#{export['id']}", name: export['filename'].to_s,
            mimeType: 'text/csv', size: export['byte_size'] }
        end

        def bearer_export?(type)
          Spree::AgentTools::CreateExport::BEARER_EXPORTS.include?(type.to_s)
        end

        def withheld(uri)
          {
            uri: uri,
            mimeType: 'text/plain',
            text: 'This export contains codes that spend money for whoever reads them, so it is ' \
                  'not readable here. Download it from the dashboard instead.'
          }
        end

        def too_large(uri, byte_size)
          {
            uri: uri,
            mimeType: 'text/plain',
            text: "This export is #{ActiveSupport::NumberHelper.number_to_human_size(byte_size)}, " \
                  'too large to read here. Download it from the dashboard, or narrow the export with ' \
                  'filters and create a smaller one.'
          }
        end
      end
    end
  end
end
