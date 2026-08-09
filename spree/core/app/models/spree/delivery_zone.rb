module Spree
  class DeliveryZone < Spree.base_class
    include Spree::SingleStoreResource

    has_prefix_id :dz

    # Single consolidated metadata JSON column (docs/plans/decisions.md
    # 2026-03-16 "Consolidate metadata") — write-only developer escape hatch.
    attribute :metadata, default: -> { {} }

    belongs_to :store, class_name: 'Spree::Store'
    # Zones are destination sets owned by a delivery profile; within it they
    # hang off an origin group, so the same profile can quote different
    # tables per warehouse. The profile's methods bind to at most one zone.
    belongs_to :delivery_profile, class_name: 'Spree::DeliveryProfile', inverse_of: :delivery_zones
    belongs_to :delivery_origin_group, class_name: 'Spree::DeliveryOriginGroup', inverse_of: :delivery_zones

    has_many :members, class_name: 'Spree::DeliveryZoneMember', dependent: :destroy, inverse_of: :delivery_zone
    has_many :delivery_methods, class_name: 'Spree::DeliveryMethod', dependent: :nullify, inverse_of: :delivery_zone

    validates :name, presence: true, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] }
    validates :store, presence: true

    # Mirrors DeliveryMethod: a zone created without an explicit profile
    # joins the store's default one, landing in its default origin group
    # unless one is named.
    before_validation :assign_default_delivery_profile, on: :create
    before_validation :assign_default_origin_group, on: :create
    validate :origin_group_must_belong_to_profile,
             if: -> { delivery_origin_group_id_changed? || delivery_profile_id_changed? }

    self.whitelisted_ransackable_attributes = %w[name]

    # @param address [Spree::Address, nil]
    # @return [Boolean] whether any member of this zone matches the address
    def include?(address)
      return false if address.nil?

      members.any? { |member| member.match?(address) }
    end

    private

    def assign_default_delivery_profile
      self.delivery_profile ||= store&.default_delivery_profile
    end

    def assign_default_origin_group
      self.delivery_origin_group ||= delivery_profile&.default_origin_group
    end

    def origin_group_must_belong_to_profile
      return if delivery_origin_group.nil? || delivery_profile.nil?
      return if delivery_origin_group.delivery_profile_id == delivery_profile_id

      errors.add(:delivery_origin_group, :invalid)
    end
  end
end
