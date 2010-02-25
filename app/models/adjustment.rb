# *Adjustment* model is a super class of all models that change order total.
#
# All adjustments associated with order are added to _item_total_.
# charges always have positive amount (they increase total),
# credits always have negative totals as they decrease the order total.
#
# h3. Basic usage
#
# Before checkout is completed, adjustments are recalculated each time #amount is called, after checkout
# all adjustments are frozen, and can be later modified, but will not be automatically recalculated.
# When displaying or using Adjustments #amount method should be always used, #update_adjustment
# and #calculate_adjustment should be considered private, and might be subject to change before 1.0.
#
# h3. Creating new Charge and Credit types
#
# When creating new type of Charge or Credit, you can either use default behaviour of Adjustment
# or override #calculate_adjustment and #applicable? to provide your own custom behaviour.
#
# All custom credits and charges should inherit either from Charge or Credit classes,
# and they name *MUST* end with either _Credit_ or _Charge_, so allowed names are for example:
# _CouponCredit_, _WholesaleCredit_ or _CodCharge_.
#
# By default Adjustment expects _adjustment_source_ to provide #calculator method
# to which _adjustment_source_ will be passed as parameter (this way adjustment source can provide
# calculator instance that is shared with other adjustment sources, or even singleton calculator).
#
class Adjustment < ActiveRecord::Base
  acts_as_list :scope => :order

  belongs_to :order
  belongs_to :adjustment_source, :polymorphic => true

  validates_presence_of :description
  validates_numericality_of :amount, :allow_nil => true

  # Tries to calculate the adjustment, returns nil if adjustment could not be calculated.
  # raises RuntimeError if adjustment source didn't provide the caculator.
  def calculate_adjustment
    if adjustment_source
      calc = adjustment_source.respond_to?(:calculator) && adjustment_source.calculator
      calc.compute(adjustment_source) if calc
    end
  end

  # Checks if adjustment is applicable for the order.
  # Should return _true_ if adjustment should be preserved and _false_ if removed.
  # Default behaviour is to preserve adjustment if amount is present and non 0.
  # Might (and should) be overriden in descendant classes, to provide adjustment specific behaviour.
  def applicable?
    amount && amount != 0
  end

  # Retrieves amount of adjustment, if order hasn't been completed and amount is not set tries to calculate new amount.
  def amount
    db_amount = read_attribute(:amount)
    if (order && order.checkout_complete)
      result = db_amount
    elsif db_amount && db_amount != 0
      result = db_amount
    else
      result = self.calculate_adjustment
    end
    return(result || 0)
  end

  def update_amount
    new_amount = calculate_adjustment
    update_attribute(:amount, new_amount) if new_amount
  end

  def secondary_type; type; end

  class << self
    public :subclasses
  end
end
