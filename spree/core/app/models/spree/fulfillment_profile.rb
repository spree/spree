module Spree
  # The grouping that decides how a set of products ships. Products
  # reference a profile directly (nil = the store's default profile); the
  # profile owns location groups, whose zones own the delivery methods.
  # Carts split per profile, and a package's candidate methods are exactly
  # its profile's methods.
  class FulfillmentProfile < Spree.base_class
    include Spree::SingleStoreResource

    has_prefix_id :fp

    acts_as_list scope: :store

    belongs_to :store, class_name: 'Spree::Store'

    has_many :location_groups, -> { order(:position) }, class_name: 'Spree::FulfillmentLocationGroup',
             dependent: :destroy, inverse_of: :fulfillment_profile
    has_many :products, class_name: 'Spree::Product', dependent: :nullify, inverse_of: :fulfillment_profile
    has_many :delivery_zones, through: :location_groups, class_name: 'Spree::DeliveryZone'
    has_many :delivery_methods, through: :location_groups, class_name: 'Spree::DeliveryMethod'

    validates :name, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }

    after_create :ensure_default_location_group

    scope :order_default, -> { order(default: :desc, position: :asc) }

    # Every store has exactly one default profile — the home of products that
    # reference none. Undeletable; demoted only by promoting another.
    def self.default_for(store)
      where(store: store, default: true).first
    end

    # The default profile is load-bearing (products fall back to it) and
    # other profiles must be empty of products before deletion.
    def can_be_deleted?
      !default? && products.none?
    end

    # The union of the profile's groups' locations — where its products can
    # be allocated from. A group with no explicit members means every store
    # location, making the whole union the full set.
    #
    # @return [ActiveRecord::Relation<Spree::StockLocation>]
    def fulfillable_stock_locations
      groups = location_groups.includes(:stock_locations).to_a
      return store.stock_locations.none if groups.empty?
      return store.stock_locations if groups.any? { |group| group.stock_locations.empty? }

      store.stock_locations.where(id: groups.flat_map { |group| group.stock_locations.map(&:id) })
    end

    private

    def ensure_default_location_group
      location_groups.create!(name: nil) if location_groups.empty?
    end
  end
end
