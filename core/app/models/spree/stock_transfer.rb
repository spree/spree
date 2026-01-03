module Spree
  class StockTransfer < Spree.base_class
    include Spree::Core::NumberGenerator.new(prefix: 'T')
    include Spree::NumberIdentifier
    include Spree::NumberAsParam
    include Spree::Metafields
    include Spree::Metadata

    publishes_lifecycle_events

    has_many :stock_movements, as: :originator
    accepts_nested_attributes_for :stock_movements, reject_if: proc { |attributes|
      attributes[:quantity] = attributes[:quantity].to_i
      attributes[:quantity].blank? || attributes[:quantity].zero? || attributes[:stock_item_id].blank?
    }

    belongs_to :source_location, class_name: 'StockLocation', optional: true
    belongs_to :destination_location, class_name: 'StockLocation'

    self.whitelisted_ransackable_attributes = %w[reference source_location_id destination_location_id number]

    validate :source_location_is_not_destination_location
    validate :stock_movements_not_empty
    validates :destination_location, presence: true

    def source_movements
      find_stock_location_with_location_id(source_location_id)
    end

    def destination_movements
      find_stock_location_with_location_id(destination_location_id)
    end

    def transfer(source_location, destination_location, variants)
      if variants.nil? || variants.empty?
        errors.add(:base, Spree.t('stock_transfer.errors.must_have_variant'))
        return false
      end

      unless variants_available_in_source_location?(source_location, variants)
        errors.add(:base, Spree.t('stock_transfer.errors.variants_unavailable'))
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

    # receive inventory from external vendor
    def receive(destination_location, variants)
      transfer(nil, destination_location, variants)
    end

    private

    def find_stock_location_with_location_id(location_id)
      stock_movements.joins(:stock_item).where('spree_stock_items.stock_location_id' => location_id)
    end

    def source_location_is_not_destination_location
      return unless source_location_id.present?
      return unless destination_location_id.present?
      return if source_location_id != destination_location_id

      errors.add(:source_location, Spree.t('stock_transfer.errors.same_location'))
    end

    def stock_movements_not_empty
      errors.add(:base, Spree.t('stock_transfer.errors.must_have_variant')) if stock_movements.empty?
    end

    def variants_available_in_source_location?(source_location, variants)
      return true if source_location.nil?

      source_location.stock_items.where(variant: variants.keys).where(Spree::StockItem.arel_table[:count_on_hand].gt(0)).size == variants.keys.size
    end
  end
end
