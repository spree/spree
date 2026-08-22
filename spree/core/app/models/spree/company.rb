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
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::HasExternalReferences

    publishes_lifecycle_events

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :companies

    has_many :company_locations, class_name: 'Spree::CompanyLocation', dependent: :destroy,
                                 inverse_of: :company
    has_many :company_contacts, through: :company_locations
    has_many :tax_identifiers, class_name: 'Spree::TaxIdentifier', dependent: :destroy,
                               inverse_of: :company
    has_many :tax_exemption_certificates, class_name: 'Spree::TaxExemptionCertificate',
                                          dependent: :destroy, inverse_of: :company

    validates :name, presence: true

    self.whitelisted_ransackable_attributes = %w[name]
    self.whitelisted_ransackable_associations = %w[company_locations external_references]

    def event_serializer_class
      'Spree::Api::V3::CompanySerializer'.safe_constantize
    end
  end
end
