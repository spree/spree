module Spree
  # Why a customer raised a claim — "arrived damaged", "never arrived",
  # "wrong item sent". A different vocabulary from {Spree::ReturnReason}:
  # a claim is about something the merchant got wrong, not about a customer
  # changing their mind.
  class ClaimReason < Spree.base_class
    has_prefix_id :clr

    include Spree::SingleStoreResource
    include Spree::Metadata

    scope :active, -> { where(active: true) }
    default_scope { order(name: :asc) }

    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    validates :name, presence: true
    # Per store, not global: two stores can each have their own "Damaged".
    unique_per_store :name, live: nil

    self.whitelisted_ransackable_attributes = %w[name active]

    has_many :claims, class_name: 'Spree::Claim', inverse_of: :reason, dependent: :restrict_with_error

    # Mirrors what `dependent: :restrict_with_error` enforces, so the dashboard
    # can hide the delete control rather than offer one the model will refuse.
    #
    # @return [Boolean]
    def can_be_deleted?
      !claims.exists?
    end
  end
end
