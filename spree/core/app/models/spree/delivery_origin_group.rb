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
    has_many :delivery_zones, class_name: 'Spree::DeliveryZone', dependent: :restrict_with_error,
             inverse_of: :delivery_origin_group
    has_many :delivery_methods, class_name: 'Spree::DeliveryMethod', dependent: :restrict_with_error,
             inverse_of: :delivery_origin_group

    delegate :store, to: :delivery_profile

    # The last group is load-bearing (zones and methods must live somewhere);
    # others go once nothing hangs off them.
    def can_be_deleted?
      delivery_zones.none? && delivery_methods.none? &&
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
