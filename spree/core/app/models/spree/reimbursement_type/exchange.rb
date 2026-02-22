class Spree::ReimbursementType::Exchange < Spree::ReimbursementType
  def self.reimburse(reimbursement, return_items, simulate)
    return [] unless return_items.present?

    exchange = Spree::Exchange.new(reimbursement.order, return_items)
    exchange.perform! unless simulate
    [exchange]
  end
end
