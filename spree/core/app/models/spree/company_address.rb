module Spree
  # An entry in a company node's address book — a labeled ship-to or bill-to
  # site. The address row is owned outright, never shared with a customer's
  # own address book, which is why it is destroyed with the entry.
  #
  # How many sites a node has never dictates how many nodes exist: structure
  # is the tree, addresses are just addresses
  # (docs/plans/6.0-b2b-companies-and-catalogs.md).
  class CompanyAddress < Spree.base_class
    has_prefix_id :caddr

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :company_addresses
    belongs_to :address, class_name: 'Spree::Address', dependent: :destroy

    # update_only, so editing one field of an existing address changes that
    # row instead of building a replacement and orphaning the old one.
    accepts_nested_attributes_for :address, update_only: true

    # The API reads and writes this under the same name, so the writer takes
    # either a record or the nested hash a client sends.
    def address=(value)
      value.is_a?(Hash) || value.is_a?(ActionController::Parameters) ? self.address_attributes = value : super
    end

    validates :address, presence: true

    # Demote any prior default in the same transaction so the partial unique
    # index ("one default of each kind per node") never sees two TRUE rows.
    # Runs before save so MySQL — which can't enforce a partial unique index —
    # also arrives at a single default (same shape as Channel#default).
    before_save :demote_other_default_billing, if: -> { default_billing? && will_save_change_to_default_billing? }
    before_save :demote_other_default_shipping, if: -> { default_shipping? && will_save_change_to_default_shipping? }

    delegate :store, :store_id, to: :company

    self.whitelisted_ransackable_attributes = %w[label default_billing default_shipping]

    private

    def demote_other_default_billing
      self.class.where(company_id: company_id, default_billing: true).where.not(id: id).update_all(default_billing: false)
    end

    def demote_other_default_shipping
      self.class.where(company_id: company_id, default_shipping: true).where.not(id: id).update_all(default_shipping: false)
    end
  end
end
