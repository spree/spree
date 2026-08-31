# frozen_string_literal: true

module Spree
  module SellerRequirements
    # A file the marketplace collects and checks — a business registration,
    # an identity document, proof of insurance. One row per document the
    # operator wants, each carrying its own instructions.
    #
    # The file lives on the submission rather than the seller: what matters
    # is which document was reviewed and by whom, and a seller may be asked
    # for a replacement without the previous one disappearing.
    class Document < Spree::SellerRequirement
      # What a business registration, an insurance certificate or an identity
      # document actually arrives as: a PDF, a photo or scan of one, or an
      # office file. Fixed rather than configurable — the answer is the same
      # for every marketplace, and asking an operator to type MIME types is a
      # way to get `image/jpg` typed and nothing accepted. Confirming the
      # type from the bytes needs the Unix `file` command on the host.
      #
      # Reopen this constant to take something else.
      ACCEPTED_CONTENT_TYPES = %w[
        application/pdf
        image/jpeg
        image/png
        image/heic
        image/webp
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
      ].freeze

      def self.allow_multiple?
        true
      end

      def self.accepts_submissions?
        true
      end

      def self.reviewed_by_operator?
        true
      end

      def self.requires_file?
        true
      end

      # A document requirement is met by an accepted submission that actually
      # carries a file — accepting an empty one would record a check nobody
      # could repeat. (A waiver settles it without one, but that is the base
      # class's business, not this method's.)
      def met_by_seller?(seller)
        submission = latest_submission(seller)

        submission.present? && submission.accepted? && submission.file.attached?
      end

      # @return [Array<String>] content types a seller may upload
      def self.accepted_content_types
        ACCEPTED_CONTENT_TYPES
      end
    end
  end
end
