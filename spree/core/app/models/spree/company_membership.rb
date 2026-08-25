module Spree
  # Joins a customer to a company node. Standing covers the node and
  # everything below it — any authorization question ("may this customer act
  # for node N") is a membership check on N's self-and-ancestors, never an
  # equality check on one node.
  #
  # Always active and always customer-backed: the not-yet-registered case is a
  # {Spree::CompanyInvitation}, never a nullable customer or a status here.
  #
  # No role column: OSS has no company permission model, and every member can
  # do everything within their standing. Enterprise brings its own
  # Spree::CompanyRole and a join onto this row — Enterprise tables reference
  # OSS rows, never the reverse — so a role column here would grant nothing
  # and be shadowed the moment it is installed.
  class CompanyMembership < Spree.base_class
    has_prefix_id :cmem

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :memberships
    belongs_to :customer, class_name: Spree.customer_class.to_s, inverse_of: :company_memberships

    validates :customer_id, uniqueness: { scope: [:company_id, *spree_base_uniqueness_scope] }

    delegate :store, :store_id, to: :company
  end
end
