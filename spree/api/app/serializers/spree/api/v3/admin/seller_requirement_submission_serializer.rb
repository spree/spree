module Spree
  module Api
    module V3
      module Admin
        # What a seller submitted about one requirement, and what was made of
        # it. The file is exposed as a URL rather than a blob id — it is what
        # the reviewer opens.
        class SellerRequirementSubmissionSerializer < BaseSerializer
          typelize status: :string, note: [:string, nullable: true],
                   review_note: [:string, nullable: true],
                   reference: [:string, nullable: true],
                   reviewed_at: [:string, nullable: true],
                   file_url: [:string, nullable: true],
                   file_name: [:string, nullable: true],
                   seller_id: :string, requirement_id: :string,
                   requirement_name: :string,
                   metadata: 'Record<string, unknown> | null'

          attributes :status, :note, :review_note, :reference, :metadata,
                     reviewed_at: :iso8601,
                     created_at: :iso8601,
                     updated_at: :iso8601

          attribute :seller_id do |submission|
            submission.seller&.prefixed_id
          end

          attribute :requirement_id do |submission|
            submission.requirement&.prefixed_id
          end

          # The reviewer is looking at a queue of these and needs to know what
          # each one answers without fetching the requirement.
          attribute :requirement_name do |submission|
            submission.requirement&.display_name
          end

          # A path to this API's own download action rather than a storage
          # URL: these are identity documents, and the download is authorized
          # per request instead of being readable by anyone holding a link.
          attribute :file_url do |submission|
            next nil unless submission.file.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_admin_seller_requirement_submission_path(
              seller_id: submission.seller.prefixed_id,
              id: submission.prefixed_id
            )
          end

          attribute :file_name do |submission|
            submission.file.attached? ? submission.file.filename.to_s : nil
          end
        end
      end
    end
  end
end
