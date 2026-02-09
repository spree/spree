Spree::Sample.load_sample('orders')

order = Spree::Order.complete.first
Spree::Reimbursement.create(order: order)
