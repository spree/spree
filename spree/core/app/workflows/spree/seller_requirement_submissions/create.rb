module Spree
  module SellerRequirementSubmissions
    # A seller records having done something the marketplace asked of them —
    # ticking an attestation, uploading a document, saying a manual check is
    # ready to run.
    #
    # Whether that settles the requirement or only queues it depends on the
    # kind: an attestation is the seller's word and is taken at face value, a
    # document or a manual check waits for someone to look at it.
    #
    # == Scanning an uploaded document
    #
    # A marketplace that runs a virus scanner hooks `after_create` and moves
    # the submission to `rejected` on a bad verdict. It must be `after_create`
    # rather than `validate`: at validate time the blob is built but not yet
    # uploaded, so there is nothing in storage to read. By `after_create` the
    # bytes are there and the submission is `pending`, a state no operator
    # acts on. A slow scanner does the same from a background job.
    #
    # Core ships no scanner — which one to run is a deployment decision. What
    # core does guarantee is that a file's type is decided by its bytes rather
    # than the uploader's header, and that its size is bounded (see
    # Spree::SellerRequirementSubmission).
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # @return [Spree::SellerRequirementSubmission]
      attr_reader :submission

      # @param seller [Spree::Seller]
      # @param requirement [Spree::SellerRequirement]
      # @param note [String, nil] what the seller wants the reviewer to know
      # @param reference [String, nil] an identifier the kind understands
      # @param file [Object, nil] an uploaded file or signed blob id
      # @param submitted_by [Object, nil] the seller's own staff member
      def perform(seller:, requirement:, note: nil, reference: nil, file: nil, submitted_by: nil)
        super

        step :ensure_submittable
        step :build_submission
        step :ensure_file_acceptable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_submission
        end

        run_hooks :after_create
        submission.publish_event('seller_requirement_submission.created')
        success(submission)
      end

      private

      # A computed requirement is answered by the seller's own data, so a
      # submission against one would be a second answer that disagrees with
      # it the moment the data changes.
      def ensure_submittable
        failure(requirement, :submissions_not_accepted) unless requirement.class.accepts_submissions?
        failure(requirement, :requirement_inactive) unless requirement.active?
      end

      def build_submission
        @submission = seller.requirement_submissions.new(
          requirement: requirement,
          status: initial_status,
          note: note,
          reference: reference,
          submitted_by: submitted_by
        )
        submission.file.attach(file) if file.present?
      end

      # A document with nothing attached records a check nobody can repeat, so
      # it is refused here rather than reaching a reviewer empty.
      #
      # Only that a file is here at all. What the file *is* — its real type
      # and its size — is the model's business, where the validation reads the
      # bytes rather than the uploader's header; repeating a weaker version of
      # that check here is how the two drift apart.
      def ensure_file_acceptable
        return unless requirement.class.requires_file?
        return if submission.file.attached?

        errors.add(:file, :blank, message: Spree.t('seller_requirements.file_required',
                                                   default: 'A file is required for this requirement'))
        failure(submission, errors)
      end

      # Waiting on a reviewer, or taken at the seller's word.
      def initial_status
        requirement.class.reviewed_by_operator? ? 'pending' : 'accepted'
      end

      def save_submission
        failure(submission, submission.errors) unless submission.save

        # Accepting at creation means nobody reviewed it — but the record
        # should still say when it was settled.
        submission.update!(reviewed_at: Time.current) if submission.accepted?
      end
    end
  end
end
