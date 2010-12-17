class LineItem < ActiveRecord::Base
  before_validation :adjust_quantity
  belongs_to :order
  belongs_to :variant

  has_one :product, :through => :variant

  before_validation :copy_price

  validates :variant, :presence => true
  validates :quantity, :numericality => { :only_integer => true, :message => I18n.t("validation.must_be_int") }
  validates :price, :numericality => true
  # validate :meta_validation_of_quantities

  attr_accessible :quantity

  before_save :update_inventory
  before_destroy :ensure_not_shipped, :remove_inventory

  after_save :update_order
  after_destroy :update_order

  def copy_price
    self.price = variant.price if variant && self.price.nil?
  end

  # def meta_validation_of_quantities
  #   unless quantity && quantity >= 0
  #     errors.add(:quantity, I18n.t("validation.must_be_non_negative"))
  #   end
  #   # avoid reload of order.inventory_units by using direct lookup
  #   unless !Spree::Config[:track_inventory_levels]                        ||
  #          Spree::Config[:allow_backorders]                               ||
  #          order   && InventoryUnit.order_id_equals(order).first.present? ||
  #          variant && quantity <= variant.on_hand
  #     errors.add(:quantity, I18n.t("validation.is_too_large") + " (#{self.variant.name})")
  #   end
  #
  #   if shipped_count = order.shipped_units.nil? ? nil : order.shipped_units[variant]
  #     errors.add(:quantity, I18n.t("validation.cannot_be_less_than_shipped_units") ) if quantity < shipped_count
  #   end
  # end

  def increment_quantity
    self.quantity += 1
  end

  def decrement_quantity
    self.quantity -= 1
  end

  def amount
    self.price * self.quantity
  end
  alias total amount

  def adjust_quantity
    self.quantity = 0 if self.quantity.nil? || self.quantity < 0
  end

  private
    def update_inventory
      return true unless self.order.completed?

      if self.new_record?
        InventoryUnit.increase(self.order, self.variant, self.quantity)
      elsif old_quantity = self.changed_attributes["quantity"]
        if old_quantity < self.quantity
          InventoryUnit.increase(self.order, self.variant, (self.quantity - old_quantity))
        elsif old_quantity > self.quantity
          InventoryUnit.decrease(self.order, self.variant, (old_quantity - self.quantity))
        end
      end

    end

    def remove_inventory
      return true unless self.order.completed?

      InventoryUnit.decrease(self.order, self.variant, self.quantity)
    end

    def update_order
      # update the order totals, etc.
      order.update!
    end

    def ensure_not_shipped
      if order.try(:inventory_units).to_a.any?{|unit| unit.variant_id == variant_id && unit.shipped?}
        errors.add :base, I18n.t("cannot_destory_line_item_as_inventory_units_have_shipped")
        return false
     end
  end
end

