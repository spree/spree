module Spree
  # Links a customer to a branch they buy for. This is what lets a signed-in
  # buyer's own cart find its company without staff touching the order.
  #
  # +role+ is a plain string with no behavior attached in 6.0 — permissions,
  # approval limits and purchase authority belong to the dedicated B2B plan.
  class CompanyContact < Spree.base_class
    has_prefix_id :cc

    belongs_to :company_location, class_name: 'Spree::CompanyLocation', inverse_of: :company_contacts
    belongs_to :customer, class_name: Spree.customer_class.to_s, inverse_of: :company_contacts

    has_one :company, through: :company_location

    validates :customer_id, uniqueness: { scope: [:company_location_id, *spree_base_uniqueness_scope] }

    delegate :store, :store_id, to: :company_location

    self.whitelisted_ransackable_attributes = %w[role]
  end
end
