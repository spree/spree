# Adjustments represent a change to the +item_total+ of an Order.  Each adjustment has an +amount+ that be either
# positive or negative.  Adjustments have two useful boolean flags
#
# +mandatory+
#
# The charge is required and will not be removed from the order, even if the amount is zero.  This is
# useful for representing things such as shipping and tax charges where you may want to make it explicitly
# clear that no charge was made for such things.
#
# +frozen+
#
# The charge is never to be udpated.  Typically you would want to freeze certain adjustments after checkout.
# One use case for this is if you want to freeze a shipping adjustment so that its value does not change
# in the future when making other trivial edits to the order (like an email change).
class Adjustment < ActiveRecord::Base
  belongs_to :order
  belongs_to :source, :polymorphic => true
  belongs_to :originator, :polymorphic => true

  validates :label, :presence => true
  validates :amount, :numericality => true

  scope :tax, lambda { where(:label => I18n.t(:tax)) }
  scope :shipping, lambda { where(:label => I18n.t(:shipping)) }
  scope :optional, where(:mandatory => false)

  # update the order totals, etc.
  after_save {order.update!}
  after_destroy {order.update!}

  # Checks if adjustment is applicable for the order. Should return _true_ if adjustment should be preserved and
  # _false_ if removed. Default behaviour is to preserve adjustment if amount is present and non 0.  Exceptions
  # are made if the adjustment is considered +mandatory+.
  def applicable?
    mandatory || amount != 0
  end

  # Tells the adjustment that its time to update itself.  Adjustments will delegate this request to their Originator
  # when present, but only if +locked+ is false.  Adjustments that are +locked+ will never change their amount.
  # The new adjustment amount will be set by by the +originator+ and is not automatically saved.  This makes it save
  # to use this method in an after_save hook for other models without causing an infinite recursion problem.  If there
  # is no +originator+ then this method will have no effect.
  def update!
    return if locked? or originator.nil?
    originator.update_adjustment(self, source)
  end
end
