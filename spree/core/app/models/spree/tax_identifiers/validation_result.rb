module Spree
  module TaxIdentifiers
    # What a validator reports back about a registration. Ephemeral: the
    # validation service is what writes it onto the row.
    class ValidationResult
      include ActiveModel::Model
      include ActiveModel::Attributes

      STATUSES = %w[verified unverified unavailable unsupported].freeze

      attribute :status, :string
      # The registry's canonical form of the number, when it reports one. Never
      # written over the entered value — the buyer's own spelling is what they
      # will recognise on an invoice.
      attribute :normalized_value, :string
      attribute :message, :string
      attribute :checked_at, :datetime

      # What was asked and what came back — the registry only ever answers
      # "valid now", so this is the only proof a past sale will have.
      attribute :evidence, default: -> { {} }

      validates :status, inclusion: { in: STATUSES }

      def verified?
        status == 'verified'
      end

      # @return [Hash] the columns {Spree::TaxIdentifiers::Validate} persists
      def to_columns
        {
          validation_status: status,
          validated_at: checked_at || Time.current,
          validation_evidence: evidence.to_h.merge(
            { 'message' => message, 'normalized_value' => normalized_value }.compact
          )
        }
      end
    end
  end
end
