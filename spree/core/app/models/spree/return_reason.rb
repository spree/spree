module Spree
  # Why a customer is sending items back — "wrong size", "changed mind",
  # "not as described". Shared by returns and exchanges.
  #
  # Renamed from Spree::ReturnAuthorizationReason in 6.0 now that the
  # ReturnAuthorization chain is gone; Spree::ReturnAuthorizationReason
  # remains as a deprecated alias for one release.
  class ReturnReason < Spree.base_class
    has_prefix_id :rar

    include Spree::NamedType
    include Spree::SingleStoreResource

    # Names are unique per store, not globally — two stores can each have
    # their own "Damaged" without colliding.
    validates :name, uniqueness: { case_sensitive: false, scope: :store_id }

    self.whitelisted_ransackable_attributes = %w[name active mutable]

    has_many :returns, class_name: 'Spree::Return', inverse_of: :reason, dependent: :restrict_with_error
    has_many :exchanges, class_name: 'Spree::Exchange', inverse_of: :reason, dependent: :restrict_with_error
  end
end
