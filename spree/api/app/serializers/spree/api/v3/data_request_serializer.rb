module Spree
  module Api
    module V3
      # Store API Data Request Serializer
      # A customer's own GDPR access or erasure request.
      class DataRequestSerializer < BaseSerializer
        typelize number: :string, kind: :string, status: :string,
                 requested_at: [:string, nullable: true],
                 completed_at: [:string, nullable: true],
                 expires_at: [:string, nullable: true],
                 download_url: [:string, nullable: true]

        attributes :number, :kind, :status

        attribute :requested_at do |data_request|
          data_request.requested_at&.iso8601
        end

        attribute :completed_at do |data_request|
          data_request.completed_at&.iso8601
        end

        attribute :expires_at do |data_request|
          data_request.expires_at&.iso8601
        end

        # Present only while the file is still there — a link the storefront
        # can render without having to reason about expiry itself.
        attribute :download_url do |data_request|
          next nil unless data_request.downloadable?

          data_request.export_file.url(expires_in: Spree::DataRequest::DEFAULT_EXPIRY)
        end
      end
    end
  end
end
