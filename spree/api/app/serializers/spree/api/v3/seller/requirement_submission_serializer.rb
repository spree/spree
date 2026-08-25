module Spree
  module Api
    module V3
      module Seller
        class RequirementSubmissionSerializer < V3::BaseSerializer
          typelize status: :string, note: [:string, nullable: true],
                   review_note: [:string, nullable: true],
                   reference: [:string, nullable: true],
                   reviewed_at: [:string, nullable: true],
                   file_url: [:string, nullable: true],
                   file_name: [:string, nullable: true]

          attributes :status, :note, :review_note, :reference,
                     reviewed_at: :iso8601,
                     created_at: :iso8601,
                     updated_at: :iso8601

          attribute :file_url do |submission|
            next nil unless submission.file.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_seller_requirement_submission_path(
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
