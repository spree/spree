Spree::Sample.load_sample('orders')

order = Spree::Order.first
Spree::Reimbursement.create(order: order)
