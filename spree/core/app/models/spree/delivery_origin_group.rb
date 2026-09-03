module Spree
  # Partitions a delivery profile's fulfillment origins: every zone and
  # method belongs to a group, so the same products can quote different
  # rates depending on which warehouse fulfills them. A profile always has
  # at least one group; the auto-created default is nameless with no
  # location members, which means every store location — simple stores
  # never see the layer.
  class DeliveryOriginGroup < Spree.base_class
    has_prefix_id :og

    acts_as_list scope: :delivery_profile

    belongs_to :delivery_profile, class_name: 'Spree::DeliveryProfile', inverse_of: :delivery_origin_groups

    has_many :delivery_origin_group_locations, class_name: 'Spree::DeliveryOriginGroupLocation',
             dependent: :destroy, inverse_of: :delivery_origin_group
    has_many :stock_locations, through: :delivery_origin_group_locations, class_name: 'Spree::StockLocation'
    # The group contains its zones and methods — that is how the dashboard
    # nests them and how a merchant reads it — so deleting the group takes
    # them with it rather than asking for them to be emptied by hand first.
    # (Destroying a zone cascades to its own methods in turn.)
    has_many :delivery_zones, class_name: 'Spree::DeliveryZone', dependent: :destroy,
             inverse_of: :delivery_origin_group
    has_many :delivery_methods, class_name: 'Spree::DeliveryMethod', dependent: :destroy,
             inverse_of: :delivery_origin_group

    delegate :store, to: :delivery_profile

    # Only one rule survives: a profile needs somewhere for delivery to live,
    # so its last group stays. Anything hanging off a group goes with it.
    def can_be_deleted?
      delivery_profile.delivery_origin_groups.where.not(id: id).exists?
    end

    # Whether packages originating from this stock location are served by
    # the group's zones and methods. No linked locations means every store
    # location.
    #
    # Allocation asks this once per location per unit, so the membership is
    # read through the loaded association rather than re-queried each call.
    #
    # @param stock_location [Spree::StockLocation, nil]
    # @return [Boolean]
    def covers_location?(stock_location)
      return false if stock_location.nil?
      return true if member_stock_location_ids.empty?
      # A narrowed group names which of the *operator's* warehouses ship this
      # kind of goods ("pallets go out of Warehouse B"), and says nothing
      # about where a seller keeps stock. Reading it as a store-wide allowlist
      # would make every seller's inventory unallocatable
      # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
      return true if stock_location.seller_id.present?

      member_stock_location_ids.include?(stock_location.id)
    end

    # @return [Array<Integer>] ids of the locations this group is limited to
    def member_stock_location_ids
      @member_stock_location_ids ||= delivery_origin_group_locations.map(&:stock_location_id)
    end

    # The locations this group fulfills from.
    #
    # @return [ActiveRecord::Relation<Spree::StockLocation>]
    def fulfillable_stock_locations
      return store.stock_locations if member_stock_location_ids.empty?

      store.stock_locations.where(id: stock_locations.select(:id))
    end
  end
end
