Spree::PaymentMethod.find_or_create_by(type: "Spree::PaymentMethod::StoreCredit", name: "Store Credit", description: "Store credit.", active: true, environment: Rails.env, display_on: 'back_end')

Spree::StoreCreditType.find_or_create_by(name: 'Expiring', priority: 1)
Spree::StoreCreditType.find_or_create_by(name: 'Non-expiring', priority: 2)

Spree::StoreCreditCategory.find_or_create_by(name: 'Gift Card')
