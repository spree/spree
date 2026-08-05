module Spree
  # Why a customer raised a claim — "arrived damaged", "never arrived",
  # "wrong item sent". A different vocabulary from {Spree::ReturnReason}:
  # a claim is about something the merchant got wrong, not about a customer
  # changing their mind.
  class ClaimReason < Spree.base_class
    has_prefix_id :clr

    include Spree::NamedType

    self.whitelisted_ransackable_attributes = %w[name active mutable]

    has_many :claims, class_name: 'Spree::Claim', inverse_of: :reason, dependent: :restrict_with_error
  end
end
