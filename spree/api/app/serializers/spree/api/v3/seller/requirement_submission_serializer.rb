module Spree
  module Api
    module V3
      module Seller
        # What this seller submitted about one requirement, and what the
        # marketplace made of it.
        #
        # Narrower than the operator's view on purpose: no `seller_id` (there
        # is exactly one seller in play and it is the caller), no
        # `requirement_name` (the checklist line already carries it), and no
        # `metadata` — that is the operator's and any provider's workspace,
        # not something a seller reads back.
        #
        # `review_note` IS included: a rejection the seller cannot read is a
        # rejection they cannot act on.
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

          # This API's own download action, not a storage URL: these are
          # identity documents, so each download is authorized per request
          # rather than readable by anyone holding the link.
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
