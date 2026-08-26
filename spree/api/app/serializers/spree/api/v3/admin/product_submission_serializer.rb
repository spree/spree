module Spree
  module Api
    module V3
      module Admin
        # A seller's request to put a product on sale, and what the
        # marketplace made of it. Extends the seller's own view with who
        # decided — the part only the operator sees.
        class ProductSubmissionSerializer < V3::Seller::ProductSubmissionSerializer
          typelize submitted_by_id: [:string, nullable: true],
                   reviewed_by_id: [:string, nullable: true],
                   reviewed_by_name: [:string, nullable: true],
                   auto_approved: :boolean,
                   metadata: 'Record<string, unknown> | null'

          attributes :metadata, updated_at: :iso8601

          attribute :submitted_by_id do |submission|
            submission.submitted_by&.prefixed_id
          end

          attribute :reviewed_by_id do |submission|
            submission.reviewed_by&.prefixed_id
          end

          # An operator reading the trail wants a name, not an id to resolve.
          attribute :reviewed_by_name do |submission|
            submission.reviewed_by&.name
          end

          # Distinguishes "the store approves listings automatically" from a
          # decision whose author we failed to record.
          attribute :auto_approved do |submission|
            submission.auto_approved?
          end
        end
      end
    end
  end
end
