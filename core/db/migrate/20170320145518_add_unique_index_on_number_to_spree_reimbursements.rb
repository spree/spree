class AddUniqueIndexOnNumberToSpreeReimbursements < ActiveRecord::Migration[5.0]
  def change
    unless index_exists?(:spree_reimbursements, :number, unique: true)
      numbers = Spree::Reimbursement.group(:number).having('sum(1) > 1').pluck(:number)
      reimbursements = Spree::Reimbursement.where(number: numbers)

      reimbursements.find_each do |reimbursement|
        reimbursement.number = reimbursement.class.number_generator.method(:generate_permalink).call(reimbursement.class)
        reimbursement.save
      end

      remove_index :spree_reimbursements, :number if index_exists?(:spree_reimbursements, :number)
      add_index :spree_reimbursements, :number, unique: true
    end
  end
end
