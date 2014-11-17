class CreateStoreCreditReimbursementType < ActiveRecord::Migration
  def change
    Spree::ReimbursementType.find_or_create_by(name: 'Store Credit', type: 'Spree::ReimbursementType::StoreCredit')
  end
end
