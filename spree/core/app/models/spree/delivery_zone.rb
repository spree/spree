module Spree
  class DeliveryZone < Spree.base_class
    include Spree::SingleStoreResource

    has_prefix_id :dz

    # Single consolidated metadata JSON column (docs/plans/decisions.md
    # 2026-03-16 "Consolidate metadata") — write-only developer escape hatch.
    attribute :metadata, default: -> { {} }

    belongs_to :store, class_name: 'Spree::Store'

    has_many :members, class_name: 'Spree::DeliveryZoneMember', dependent: :destroy, inverse_of: :delivery_zone
    has_many :delivery_method_zones, class_name: 'Spree::DeliveryMethodZone', dependent: :destroy, inverse_of: :delivery_zone
    has_many :delivery_methods, through: :delivery_method_zones, class_name: 'Spree::DeliveryMethod'

    validates :name, presence: true, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] }
    validates :store, presence: true, unless: -> { Spree::Config[:disable_store_presence_validation] }

    self.whitelisted_ransackable_attributes = %w[name]

    # @param address [Spree::Address, nil]
    # @return [Boolean] whether any member of this zone matches the address
    def include?(address)
      return false if address.nil?

      members.any? { |member| member.match?(address) }
    end
  end
end
