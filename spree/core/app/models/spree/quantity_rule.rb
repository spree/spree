module Spree
  # A resolved pair of purchasing rules for one variant and one buyer: the
  # least they may order and the increment they must land on. MOQ 48 with
  # multiple 24 admits 48, 72, 96 and refuses 50.
  #
  # Resolution (variant base -> catalog default -> catalog x variant
  # override) happens in {Spree::Catalogs::ResolveQuantityRules}; this object
  # is only the answer and the arithmetic over it, so the same rules apply
  # identically wherever a quantity is checked or a stepper is drawn.
  class QuantityRule
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :minimum_order_quantity, :integer
    attribute :order_multiple, :integer

    # The rule every buyer gets when nothing declares one: buy one at a time.
    def self.default
      new
    end

    # @return [Integer] the least quantity that may be ordered
    def minimum
      value = minimum_order_quantity.to_i
      value.positive? ? value : 1
    end

    # @return [Integer] the increment quantities must land on
    def multiple
      value = order_multiple.to_i
      value.positive? ? value : 1
    end

    # True when neither rule narrows anything — the shape a retail buyer sees.
    # @return [Boolean]
    def unrestricted?
      minimum == 1 && multiple == 1
    end

    # @param quantity [Integer]
    # @return [Boolean]
    def satisfied_by?(quantity)
      quantity = quantity.to_i
      quantity >= minimum && ((quantity - offset) % multiple).zero?
    end

    # The largest valid quantity at or below the given one, or nil when the
    # minimum is already above it.
    # @param quantity [Integer]
    # @return [Integer, nil]
    def previous_valid(quantity)
      quantity = quantity.to_i
      return nil if quantity < minimum

      quantity - ((quantity - offset) % multiple)
    end

    # The smallest valid quantity at or above the given one.
    # @param quantity [Integer]
    # @return [Integer]
    def next_valid(quantity)
      quantity = quantity.to_i
      return minimum if quantity <= minimum

      remainder = (quantity - offset) % multiple
      remainder.zero? ? quantity : quantity + (multiple - remainder)
    end

    # The valid quantities either side of an invalid one, used to tell a buyer
    # what they may order instead. Both are present unless the quantity is
    # below the minimum, where there is nothing lower to offer.
    #
    # @param quantity [Integer]
    # @return [Array<Integer>] one or two ascending quantities
    def nearest_valid(quantity)
      [previous_valid(quantity), next_valid(quantity)].compact.uniq
    end

    # Steps are counted from the minimum rather than from zero, so a rule of
    # "at least 50, in 24s" offers 50 / 74 / 98 instead of refusing its own
    # minimum. A minimum that already sits on the multiple leaves this at 0
    # and the arithmetic is the plain modulo it looks like.
    def offset
      minimum % multiple
    end

    def ==(other)
      other.is_a?(self.class) && minimum == other.minimum && multiple == other.multiple
    end
    alias eql? ==

    def hash
      [minimum, multiple].hash
    end
  end
end
