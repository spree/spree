module Spree
  module Api
    module V3
      module Seller
        # One of a seller's CSV imports, as their panel's wizard reads it: the
        # mapping payload while `mapping`, the poll counters afterwards.
        #
        # Declared from the store base rather than the admin serializer, like
        # every serializer on this branch — the two are parallel, and an admin
        # serializer gaining an operator-only field would otherwise leak it
        # here. The fields below are the wizard's own working data (what the
        # seller uploaded, how its columns map, how many rows have landed), so
        # they are restated rather than inherited.
        class ImportSerializer < V3::ImportSerializer
          typelize completed_rows_count: :number,
                   failed_rows_count: :number,
                   processing_errors: [:string, nullable: true],
                   preferred_delimiter: :string,
                   schema_fields: 'Array<{ name: string; label: string; required: boolean }>',
                   csv_headers: [:string, multi: true],
                   sample_row: 'Record<string, string | null>',
                   original_filename: [:string, nullable: true],
                   original_byte_size: [:number, nullable: true],
                   original_file_url: [:string, nullable: true]

          attributes :processing_errors, :preferred_delimiter

          # The file the seller uploaded. `original_file_url` is this branch's
          # own streaming endpoint (JWT-authenticated), not a signed
          # ActiveStorage URL — the panel's `/api/*` proxy would not carry one.
          attribute :original_filename do |import|
            import.attachment.blob&.filename&.to_s if import.attachment.attached?
          end

          attribute :original_byte_size do |import|
            import.attachment.blob&.byte_size if import.attachment.attached?
          end

          attribute :original_file_url do |import|
            next nil unless import.attachment.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_seller_import_path(
              id: import.prefixed_id
            )
          end

          attribute :completed_rows_count do |import|
            import.rows_status_counts['completed'] || 0
          end

          attribute :failed_rows_count do |import|
            import.rows_status_counts['failed'] || 0
          end

          attribute :schema_fields do |import|
            import.schema_fields.map do |field|
              { name: field[:name], label: field[:label], required: field[:required].present? }
            end
          end

          # Mapping-state only: these read the attached blob, which the 2s
          # processing poll must never do.
          attribute :csv_headers do |import|
            import.mapping? ? (import.csv_headers || []) : []
          end

          attribute :sample_row do |import|
            import.mapping? ? import.sample_row : {}
          end

          many :mappings,
               resource: proc { Spree.api.seller_import_mapping_serializer }
        end
      end
    end
  end
end
