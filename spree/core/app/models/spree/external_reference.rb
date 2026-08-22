module Spree
  # Maps a Spree record to its identity in an external system — the key an ERP,
  # PIM, DAM or CRM knows it by. A record can carry one reference per system, so
  # a product known to both a PIM and an ERP under different keys needs no
  # per-system column.
  #
  # +system+ is a plain string key rather than a foreign key to
  # {Spree::Integration}: data arrives from systems that have no live connector
  # (a nightly CSV from a legacy PIM), and those still need somewhere to record
  # their identity. Where a connector does exist the convention is to reuse its
  # integration's +api_type+, so connector, references and settings page agree
  # on the name.
  class ExternalReference < Spree.base_class
    has_prefix_id :extref

    include Spree::SingleStoreResource
    include Spree::Metadata

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :external_references
    belongs_to :resource, polymorphic: true

    normalizes :system, with: ->(value) { value.to_s.strip.downcase }
    normalizes :external_id, with: ->(value) { value.to_s.strip }

    validates :system, :external_id, presence: true
    validates :system,
              format: { with: /\A[a-z0-9_]+\z/, message: :invalid_system_key },
              allow_blank: true
    # Both directions, each backed by a unique index: one reference per system
    # per record, and one record per external id.
    validates :resource_id,
              uniqueness: { scope: [:store_id, :system, :resource_type, *spree_base_uniqueness_scope] },
              allow_blank: true
    validates :external_id,
              uniqueness: { scope: [:store_id, :system, :resource_type, *spree_base_uniqueness_scope] },
              allow_blank: true

    self.whitelisted_ransackable_attributes = %w[system external_id resource_type]

    scope :for_system, ->(system) { where(system: system.to_s.strip.downcase) }
  end
end
