module Spree
  # A business customer — the entity an invoice is addressed to, as distinct
  # from the person who placed the order. Carries the tax registration and the
  # exemption certificates that decide how its purchases are taxed.
  #
  # Deliberately minimal: this is the part of the B2B model that tax needs
  # (docs/plans/6.0-tax-provider.md Phase 7). Assortment, negotiated pricing
  # and buyer roles belong to docs/plans/6.1-channels-catalogs-b2b.md, which
  # extends these models rather than redefining them.
  class Company < Spree.base_class
    has_prefix_id :comp

    include Spree::SingleStoreResource
    include Spree::Metafields

    publishes_lifecycle_events

    # Single consolidated metadata JSON column (docs/plans/decisions.md
    # 2026-03-16 "Consolidate metadata") — write-only developer escape hatch.
    attribute :metadata, default: -> { {} }

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :companies

    has_many :company_locations, class_name: 'Spree::CompanyLocation', dependent: :destroy,
                                 inverse_of: :company
    has_many :company_contacts, through: :company_locations

    validates :name, presence: true
    # Paired with the partial unique index, per the convention — without it a
    # duplicate reference reaches the database and surfaces as a 500 rather
    # than a validation error. Nil is exempt on both sides.
    validates :external_id, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] }, allow_nil: true

    self.whitelisted_ransackable_attributes = %w[name external_id]
    self.whitelisted_ransackable_associations = %w[company_locations]

    def event_serializer_class
      'Spree::Api::V3::CompanySerializer'.safe_constantize
    end
  end
end
