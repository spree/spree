class LineItem < ActiveRecord::Base
  before_validation :adjust_quantity
  belongs_to :order
  belongs_to :variant

  has_one :product, :through => :variant

  before_validation :copy_price
  before_destroy :ensure_not_shipped

  validates_presence_of :variant, :order
  validates_numericality_of :quantity, :only_integer => true, :message => I18n.t("validation.must_be_int")
  validates_numericality_of :price

  attr_accessible :quantity, :variant_id, :order_id

  def copy_price
    self.price = variant.price if variant && self.price.nil?
  end

  def validate
    unless quantity && quantity >= 0
      errors.add(:quantity, I18n.t("validation.must_be_non_negative"))
    end
    # avoid reload of order.inventory_units by using direct lookup
    unless !Spree::Config[:track_inventory_levels]                        ||
           Spree::Config[:allow_backorders]                               ||
           order   && InventoryUnit.order_id_equals(order).first.present? ||
           variant && quantity <= variant.on_hand
      errors.add(:quantity, I18n.t("validation.is_too_large") + " (#{self.variant.name})")
    end

    if shipped_count = order.shipped_units.nil? ? nil : order.shipped_units[variant]
      errors.add(:quantity, I18n.t("validation.cannot_be_less_than_shipped_units") ) if quantity < shipped_count
    end
  end

  def increment_quantity
    self.quantity += 1
  end

  def decrement_quantity
    self.quantity -= 1
  end

  def total
    self.price * self.quantity
  end
  alias amount total

  def adjust_quantity
    self.quantity = 0 if self.quantity.nil? || self.quantity < 0
  end

  private
  def ensure_not_shipped
    if shipped_count = order.shipped_units.nil? ? nil : order.shipped_units[variant]
      errors.add_to_base I18n.t("cannot_destory_line_item_as_inventory_units_have_shipped")
      return false
    end
  end
end

