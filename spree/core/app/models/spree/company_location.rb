module Spree
  # A branch or office of a business customer. Reaches the store through its
  # company and so carries no store_id of its own.
  #
  # Its addresses are created inline and owned outright — a branch address is
  # the branch's, not a row shared with the buyer's address book, which is why
  # they are destroyed with it (docs/plans/decisions.md 2026-08-07).
  class CompanyLocation < Spree.base_class
    has_prefix_id :cloc

    include Spree::Metafields

    attribute :metadata, default: -> { {} }

    belongs_to :company, class_name: 'Spree::Company', inverse_of: :company_locations
    belongs_to :billing_address, class_name: 'Spree::Address', optional: true, dependent: :destroy
    belongs_to :shipping_address, class_name: 'Spree::Address', optional: true, dependent: :destroy

    accepts_nested_attributes_for :billing_address
    accepts_nested_attributes_for :shipping_address

    has_many :company_contacts, class_name: 'Spree::CompanyContact', dependent: :destroy,
                                inverse_of: :company_location
    has_many :customers, through: :company_contacts, source: :customer

    validates :name, presence: true

    delegate :store, :store_id, to: :company

    self.whitelisted_ransackable_attributes = %w[name external_id]
  end
end
