module Spree
  module Api
    module V3
      # The `download` action for a private attachment — an invoice, an order
      # document — streamed through the API in chunks rather than linked to
      # storage, so the credentials that reached the action protect the file.
      # The including controller fetches and authorizes `@resource` first.
      module StreamsPrivateFile
        extend ActiveSupport::Concern

        included do
          include ActiveStorage::Streaming
        end

        # GET .../:id/download
        def download
          send_blob_stream(private_file.blob, disposition: :attachment)
        end

        protected

        # @return [ActiveStorage::Attached::One]
        def private_file
          @resource.file
        end
      end
    end
  end
end
