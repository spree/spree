module Spree
  # The grouping that decides how a set of products ships: which origins can
  # fulfill them, which destination zones apply, and which delivery methods
  # are offered. Products reference a profile directly (nil = the store's
  # default profile); carts split per profile, and a package's candidate
  # methods are exactly its profile's methods.
  #
  # Formerly Spree::ShippingCategory — the table is renamed in place, so 5.x
  # category assignments become profile assignments (see
  # docs/plans/6.0-delivery-profiles.md).
  class DeliveryProfile < Spree.base_class
    include Spree::SingleStoreResource

    has_prefix_id :fp

    acts_as_list scope: :store

    belongs_to :store, class_name: 'Spree::Store', optional: true

    has_many :products, class_name: 'Spree::Product', dependent: :restrict_with_error, inverse_of: :delivery_profile
    # Origin groups partition the profile's fulfillment origins; zones and
    # methods hang off a group, so per-origin rate tables need no second
    # profile. Every profile has at least one (the nameless default, whose
    # empty membership means every store location).
    has_many :delivery_origin_groups, -> { order(:position) }, class_name: 'Spree::DeliveryOriginGroup',
             dependent: :destroy, inverse_of: :delivery_profile
    has_many :delivery_zones, class_name: 'Spree::DeliveryZone', dependent: :destroy,
             inverse_of: :delivery_profile
    has_many :delivery_methods, class_name: 'Spree::DeliveryMethod', dependent: :destroy,
             inverse_of: :delivery_profile

    after_create :create_default_origin_group

    validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :store_id }

    registers_subclasses_via { Spree.delivery_profile_types }

    # Whether a delivery method using the given fulfillment provider may
    # join this profile — the guard that keeps a Digital profile from
    # quietly gaining a shipping method and reinterpreting its products.
    #
    # @param _provider_class [Class] a Spree::FulfillmentProvider subclass
    # @return [Boolean]
    def accepts_provider?(_provider_class)
      true
    end

    # Whether this profile's products are delivered digitally. Declared by
    # the kind, not derived from the method set — a freshly created profile
    # with no methods yet must already know what it is.
    def digital?
      false
    end

    # Whether checkout must collect a shipping address for this profile's
    # products. Kinds override; the physical default derives from methods'
    # providers (a pickup-only profile needs none).
    def requires_shipping_address?
      delivery_methods.any?(&:requires_address?)
    end

    # Whether this profile's products can be collected at a merchant counter
    # — true when any of its methods hands goods over via a pickup provider.
    def offers_pickup?
      delivery_methods.any?(&:pickup?)
    end

    # Whether this profile's products ship to a customer address.
    def offers_shipping?
      delivery_methods.any?(&:requires_address?)
    end

    before_save :ensure_one_default

    scope :order_default, -> { order(default: :desc, position: :asc) }

    # The profile products fall back to when they reference none. Every
    # store has exactly one.
    #
    # @param store [Spree::Store]
    # @return [Spree::DeliveryProfile, nil]
    def self.default_for(store)
      where(store: store, default: true).first
    end

    # The default profile is load-bearing (products fall back to it); other
    # profiles must be empty of products first.
    def can_be_deleted?
      !default? && products.none?
    end

    # Whether packages originating from this stock location can carry the
    # profile's products — true when any origin group covers it.
    #
    # @param stock_location [Spree::StockLocation, nil]
    # @return [Boolean]
    def covers_location?(stock_location)
      return false if stock_location.nil?

      delivery_origin_groups.any? { |group| group.covers_location?(stock_location) }
    end

    # The locations this profile's products may be allocated from — the
    # union of its origin groups' locations. Any group with no members
    # widens the union to every store location.
    #
    # @return [ActiveRecord::Relation<Spree::StockLocation>]
    def fulfillable_stock_locations
      groups = delivery_origin_groups.includes(:delivery_origin_group_locations)
      # Any group without members widens the union to every store location.
      return store.stock_locations if groups.empty? || groups.any? { |group| group.member_stock_location_ids.empty? }

      store.stock_locations.where(id: groups.flat_map(&:member_stock_location_ids).uniq)
    end

    # The group zones and methods join when none is named — the first by
    # position, which for untouched profiles is the auto-created default.
    #
    # @return [Spree::DeliveryOriginGroup, nil]
    def default_origin_group
      delivery_origin_groups.first
    end

    private

    def create_default_origin_group
      delivery_origin_groups.create!
    end

    # Mirrors StockLocation#ensure_one_default: promoting a profile demotes
    # the previous default; the default flag can never be simply removed.
    def ensure_one_default
      if default?
        Spree::DeliveryProfile.where(store_id: store_id, default: true).where.not(id: id).update_all(default: false)
      elsif default_was && will_save_change_to_default?
        self.default = true
      end
    end
  end
end
