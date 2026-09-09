module Spree
  module Api
    module V3
      # The event shape for `data_request.*`.
      #
      # Deliberately not the store serializer: that one carries `download_url`,
      # a working unauthenticated link to a person's entire personal-data
      # export. An event goes to every subscribed endpoint and is persisted in
      # the delivery log, so a subscriber would receive the credential and a
      # copy would sit in a queryable admin-readable column for the life of the
      # log. Subscribers get the fact that a request finished; fetching the
      # file stays an authenticated act by the person it belongs to.
      class DataRequestEventSerializer < BaseSerializer
        typelize number: :string, kind: :string, status: :string,
                 requested_at: [:string, nullable: true],
                 completed_at: [:string, nullable: true]

        attributes :number, :kind, :status

        attribute :requested_at do |data_request|
          data_request.requested_at&.iso8601
        end

        attribute :completed_at do |data_request|
          data_request.completed_at&.iso8601
        end
      end
    end
  end
end
