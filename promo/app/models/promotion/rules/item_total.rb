# A rule to limit a promotion to a specific user.
class Promotion::Rules::ItemTotal < PromotionRule

  preference :amount, :decimal, :default => 100.00
  preference :operator, :string, :default => '>'

  OPERATORS = ['gt', 'gte']

  def eligible?(order)
    order.item_total.send(preferred_operator == 'gte' ? :>= : :>, preferred_amount)
  end

end
