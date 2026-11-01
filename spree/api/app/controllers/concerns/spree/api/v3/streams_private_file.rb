module Spree
  module Api
    module V3
      # Serving a private attachment — an invoice, an order document — through
      # the API rather than a storage link, so the credentials that reached the
      # action are what protect the file. The caller has already fetched and
      # authorized the record.
      module StreamsPrivateFile
        extend ActiveSupport::Concern

        included do
          include ActiveStorage::SetCurrent
        end

        # @param attachment [ActiveStorage::Attached::One]
        def stream_private_file(attachment)
          send_data(
            attachment.download,
            filename: attachment.filename.to_s,
            type: attachment.content_type || 'application/octet-stream',
            disposition: 'attachment'
          )
        end
      end
    end
  end
end
