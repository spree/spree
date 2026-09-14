module Spree
  # Why a customer is sending items back — "wrong size", "changed mind",
  # "not as described". Shared by returns and exchanges.
  #
  # Renamed from Spree::ReturnAuthorizationReason in 6.0 now that the
  # ReturnAuthorization chain is gone; Spree::ReturnAuthorizationReason
  # remains as a deprecated alias for one release.
  class ReturnReason < Spree.base_class
    has_prefix_id :rar

    include Spree::SingleStoreResource

    scope :active, -> { where(active: true) }
    default_scope { order(name: :asc) }

    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    validates :name, presence: true
    # Per store, not global: two stores can each have their own "Damaged".
    unique_per_store :name, live: nil

    self.whitelisted_ransackable_attributes = %w[name active]

    has_many :returns, class_name: 'Spree::Return', inverse_of: :reason, dependent: :restrict_with_error
    has_many :exchanges, class_name: 'Spree::Exchange', inverse_of: :reason, dependent: :restrict_with_error

    # Mirrors what `dependent: :restrict_with_error` enforces, so the dashboard
    # can hide the delete control rather than offer one the model will refuse.
    #
    # @return [Boolean]
    def can_be_deleted?
      !returns.exists? && !exchanges.exists?
    end
  end
end
