class CreateSpreePaymentMethodStoreCredits < ActiveRecord::Migration
  def up
    return if Spree::PaymentMethod.find_by_type("Spree::PaymentMethod::StoreCredit")
    Spree::PaymentMethod.create(type: "Spree::PaymentMethod::StoreCredit", name: "Store Credit", description: "Store credit.", active: true, environment: Rails.env)
  end
end
