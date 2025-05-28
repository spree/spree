module Spree
  class StockLocation < Spree.base_class
    include Spree::UniqueName
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end
    if defined?(Spree::Security::StockLocations)
      include Spree::Security::StockLocations
    end
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end

    acts_as_paranoid

    has_many :shipments
    has_many :stock_items, dependent: :delete_all, inverse_of: :stock_location
    has_many :variants, through: :stock_items
    has_many :stock_movements, through: :stock_items

    belongs_to :state, class_name: 'Spree::State', optional: true
    belongs_to :country, class_name: 'Spree::Country'

    scope :active, -> { where(active: true) }
    scope :order_default, -> { order(default: :desc, name: :asc) }

    after_create :create_stock_items, if: :propagate_all_variants?
    after_save :ensure_one_default
    after_update :conditional_touch_records

    delegate :name, :iso3, :iso, :iso_name, to: :country, prefix: true

    def state_text
      state.try(:abbr) || state.try(:name) || state_name
    end

    # Wrapper for creating a new stock item respecting the backorderable config
    def propagate_variant(variant)
      stock_items.create!(variant: variant, backorderable: backorderable_default)
    end

    # Return either an existing stock item or create a new one. Useful in
    # scenarios where the user might not know whether there is already a stock
    # item for a given variant
    def set_up_stock_item(variant)
      stock_item(variant) || propagate_variant(variant)
    end

    # Returns an instance of StockItem for the variant id.
    #
    # @param variant_id [String] The id of a variant.
    #
    # @return [StockItem] Corresponding StockItem for the StockLocation's variant.
    def stock_item(variant_id)
      stock_items.where(variant_id: variant_id).order(:id).first
    end

    def stocks?(variant)
      stock_items.exists?(variant: variant)
    end

    # Attempts to look up StockItem for the variant, and creates one if not found.
    #
    # @param variant Variant instance or Variant ID
    #
    # @return [StockItem] Corresponding StockItem for the StockLocation's variant.
    def stock_item_or_create(variant_or_variant_id)
      if variant_or_variant_id.is_a?(Spree::Variant)
        variant_id = variant_or_variant_id.id
        variant = variant_or_variant_id
      else
        variant_id = variant_or_variant_id
        variant = Spree::Variant.find(variant_or_variant_id)
      end
      stock_item(variant_id) || propagate_variant(variant)
    end

    # Returns the count on hand number for the variant
    #
    # @param variant Variant instance
    #
    # @return [Integer]
    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end

    def backorderable?(variant)
      stock_item(variant).try(:backorderable?)
    end

    def restock(variant, quantity, originator = nil, persist: true)
      move(variant, quantity, originator, persist: persist)
    end

    def restock_backordered(variant, quantity, _originator = nil)
      item = stock_item_or_create(variant)
      item.update_columns(
        count_on_hand: item.count_on_hand + quantity,
        updated_at: Time.current
      )
    end

    def unstock(variant, quantity, originator = nil, persist: true)
      move(variant, -quantity, originator, persist: persist)
    end

    def move(variant, quantity, originator = nil, persist: true)
      stock_item = stock_item_or_create(variant)

      if persist
        stock_item.stock_movements.create!(quantity: quantity, originator: originator)
      else
        originator.stock_movements << stock_item.stock_movements.build(quantity: quantity)
      end
    end

    def fill_status(variant, quantity)
      if item = stock_item_or_create(variant)
        if item.count_on_hand >= quantity
          on_hand = quantity
          backordered = 0
        else
          on_hand = item.count_on_hand
          on_hand = 0 if on_hand < 0
          backordered = item.backorderable? ? (quantity - on_hand) : 0
        end

        [on_hand, backordered]
      else
        [0, 0]
      end
    end

    def address
      Spree::Address.new(
        address1: address1,
        address2: address2,
        company: company,
        city: city,
        state: state,
        state_name: state_name,
        country: country,
        zipcode: zipcode,
        phone: phone
      )
    end

    # needed for address form
    def require_name?
      false
    end

    # needed for address form
    def require_company?
      false
    end

    def require_phone?
      false
    end

    def show_company_address_field?
      true
    end

    def display_name
      @display_name ||= [admin_name, name].delete_if(&:blank?).join(' / ')
    end

    private

    def create_stock_items
      Spree::StockLocations::StockItems::CreateJob.perform_later(self)
    end

    def ensure_one_default
      if default
        StockLocation.where(default: true).where.not(id: id).update_all(default: false)
        StockLocation.where.not(id: id).update_all(updated_at: Time.current)
      end
    end

    def conditional_touch_records
      return unless active_changed?

      stock_items.update_all(updated_at: Time.current)
      variants.update_all(updated_at: Time.current)
    end
  end
end
