module Spree
  class StockTransfer < Spree.base_class
    has_prefix_id :st

    has_spree_number prefix: 'T'
    include Spree::NumberIdentifier
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    # No `dependent:` option, for the reason given on Spree::Fulfillment's own
    # movements: the ledger outlives the record that caused it.
    has_many :stock_movements, class_name: 'Spree::StockMovement', inverse_of: :stock_transfer
    accepts_nested_attributes_for :stock_movements, reject_if: proc { |attributes|
      attributes[:quantity] = attributes[:quantity].to_i
      attributes[:quantity].blank? || attributes[:quantity].zero? || attributes[:stock_level_id].blank?
    }

    belongs_to :source_location, class_name: 'StockLocation', optional: true
    belongs_to :destination_location, class_name: 'StockLocation'

    self.whitelisted_ransackable_attributes = %w[reference source_location_id destination_location_id number]

    validate :source_location_is_not_destination_location
    validate :stock_movements_not_empty

    # Transfers have no store of their own — they belong to the warehouses
    # they move stock between, and those are store-scoped. Used by
    # {Spree::HasNumber} to pick up the store's numbering settings.
    #
    # @return [Spree::Store, nil]
    def number_store
      destination_location&.store || source_location&.store || super
    end

    def source_movements
      find_stock_location_with_location_id(source_location_id)
    end

    def destination_movements
      find_stock_location_with_location_id(destination_location_id)
    end

    def transfer(source_location, destination_location, variants)
      if variants.nil? || variants.empty?
        errors.add(:base, :must_have_variant, message: Spree.t('stock_transfer.errors.must_have_variant'))
        return false
      end

      # Before the availability check, which a negative quantity would sail
      # through — every count is greater than a negative number. The move would
      # then write a negative in both directions and take stock off the source
      # *and* the destination.
      unless positive_quantities?(variants)
        errors.add(:base, :invalid_quantity, message: Spree.t('stock_transfer.errors.invalid_quantity'))
        return false
      end

      unless variants_available_in_source_location?(source_location, variants)
        errors.add(:base, :variants_unavailable, stock: source_location.name,
                   message: Spree.t('stock_transfer.errors.variants_unavailable', stock: source_location.name))
        return false
      end

      transaction do
        variants.each_pair do |variant, quantity|
          source_location&.unstock(variant, quantity, self, persist: false)
          destination_location.restock(variant, quantity, self, persist: false)

          self.source_location = source_location
          self.destination_location = destination_location
          save!
        end
      end

      true
    end

    # receive inventory from external seller
    def receive(destination_location, variants)
      transfer(nil, destination_location, variants)
    end

    private

    def find_stock_location_with_location_id(location_id)
      stock_movements.joins(:stock_level).
        where(Spree::StockLevel.table_name => { stock_location_id: location_id })
    end

    def source_location_is_not_destination_location
      return unless source_location_id.present?
      return unless destination_location_id.present?
      return if source_location_id != destination_location_id

      errors.add(:source_location, :same_location, message: Spree.t('stock_transfer.errors.same_location'))
    end

    def stock_movements_not_empty
      errors.add(:base, :must_have_variant, message: Spree.t('stock_transfer.errors.must_have_variant')) if stock_movements.empty?
    end

    # Each variant needs enough available stock for the quantity being moved,
    # not merely some. Checking only for a positive balance let a transfer take
    # more than the shelf held and leave it negative.
    def positive_quantities?(variants)
      variants.all? { |_variant, quantity| quantity.to_i.positive? }
    end

    def variants_available_in_source_location?(source_location, variants)
      return true if source_location.nil?

      variants.all? do |variant, quantity|
        stock_level = source_location.stock_level(variant)

        stock_level.present? && stock_level.available_count >= quantity.to_i
      end
    end
  end
end
