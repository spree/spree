module Spree
  # Stock moving between two of the merchant's own warehouses
  # (docs/plans/6.0-inventory-operations.md).
  #
  # A transfer is a trip, not an instant. Units leave the source when
  # {Spree::StockTransfers::MarkInTransit} runs and land at the destination
  # when {Spree::StockTransfers::Receive} does — in between they are in flight,
  # physically gone from one shelf and not yet on the other. The 5.x model
  # collapsed both into one transaction, which made the destination's
  # availability wrong for the whole journey.
  #
  # Every status change is a workflow, never `transfer.receive!`, so receiving
  # can carry the quantities the warehouse actually counted and cancelling can
  # carry the merchant's restock-or-write-off choice.
  #
  # Receiving from a supplier is a {Spree::PurchaseOrder}, not a transfer with
  # no source: a purchase has a cost, a supplier and an expected date, and none
  # of those belong on internal logistics.
  class StockTransfer < Spree.base_class
    has_prefix_id :st

    # Before `has_spree_number`, deliberately: both register a
    # `before_validation`, and numbering reads the store to pick up its
    # sequence. Registered the other way round, a transfer built without an
    # explicit store would draw its number from the default store's counter.
    include Spree::SingleStoreResource
    has_spree_number prefix: 'T'
    include Spree::NumberIdentifier
    include Spree::HasStatus
    include Spree::Receivable
    include Spree::HasCustomFields
    include Spree::Metadata

    # The upgrade task keeps a converted external receive's number readable by
    # stamping the row rather than deleting it.
    acts_as_paranoid

    publishes_lifecycle_events

    has_status :draft, :ready_to_ship, :in_transit, :partially_received, :received, :over_received, :canceled,
               default: :draft

    belongs_to :source_location, class_name: 'Spree::StockLocation'
    belongs_to :destination_location, class_name: 'Spree::StockLocation'
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :items, class_name: 'Spree::StockTransferItem',
                     inverse_of: :stock_transfer, dependent: :destroy
    # No `dependent:`, for the reason given on Spree::Fulfillment's own
    # movements: the ledger outlives the record that caused it.
    has_many :stock_movements, class_name: 'Spree::StockMovement', inverse_of: :stock_transfer

    accepts_nested_attributes_for :items, allow_destroy: true

    validates :source_location, :destination_location, presence: true
    # A document that has left draft describes a box that physically exists —
    # except a cancelled one, which describes a trip that never happened. The
    # guard covers both because `update` assigns the status before validating,
    # so cancelling an empty draft would otherwise be refused.
    validates :items, presence: true, unless: -> { draft? || canceled? }
    validate :source_location_is_not_destination_location
    validate :locations_belong_to_the_same_store

    self.whitelisted_ransackable_attributes = %w[number status reference source_location_id
                                                 destination_location_id shipped_at received_at
                                                 closed_short_at created_at]
    self.whitelisted_ransackable_scopes = %w[open closed]
    self.whitelisted_ransackable_associations = %w[source_location destination_location items]

    # Whether the merchant may still edit the lines. Once the box is sealed and
    # marked ready, what is in it is a matter of record.
    #
    # @return [Boolean]
    def editable?
      draft?
    end

    # Whether the units are somewhere between the two warehouses — gone from
    # the source, not yet counted at the destination.
    #
    # @return [Boolean]
    def in_flight?
      in_transit? || partially_received?
    end

    private

    # The warehouse the goods are going to decides whose transfer this is,
    # which is a fact about the record rather than about the request that
    # created it. `Spree::Current.store` stays the fallback.
    def ensure_store
      self.store ||= destination_location&.store
      super
    end

    def source_location_is_not_destination_location
      return if source_location_id.blank? || destination_location_id.blank?
      return if source_location_id != destination_location_id

      errors.add(:source_location, :same_location, message: Spree.t('stock_transfer.errors.same_location'))
    end

    # A transfer moves a merchant's own stock between their own warehouses. Two
    # locations from different stores would take units out of one tenant's
    # inventory and put them into another's.
    def locations_belong_to_the_same_store
      return if source_location.blank? || destination_location.blank?
      return if source_location.store_id == destination_location.store_id

      errors.add(:destination_location, :must_belong_to_same_store,
                 message: Spree.t('stock_transfer.errors.locations_in_different_stores'))
    end
  end
end
