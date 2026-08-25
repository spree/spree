module Spree
  # Joins a customer to a company node. Standing covers the node and
  # everything below it — any authorization question ("may this customer act
  # for node N") is a membership check on N's self-and-ancestors, never an
  # equality check on one node.
  #
  # Always active and always customer-backed: the not-yet-registered case is a
  # {Spree::CompanyInvitation}, never a nullable customer or a status here.
  #
  # +role+ is a cosmetic label with no behavior attached — OSS has no company
  # permission model; every member can do everything within their standing.
  # The capability model is Enterprise (docs/plans/6.0-admin-rbac.md).
  class CompanyMembership < Spree.base_class
    has_prefix_id :cmem

    attribute :role, :string, default: 'buyer'

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :memberships
    belongs_to :customer, class_name: Spree.customer_class.to_s, inverse_of: :company_memberships

    validates :customer_id, uniqueness: { scope: [:company_id, *spree_base_uniqueness_scope] }

    delegate :store, :store_id, to: :company

    self.whitelisted_ransackable_attributes = %w[role]
  end
end
