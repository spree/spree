class AddUniqueIndexOnNumberToSpreeReturnAuthorizations < ActiveRecord::Migration[5.0]
  def change
    unless index_exists?(:spree_return_authorizations, :number, unique: true)
      numbers = Spree::ReturnAuthorization.group(:number).having('sum(1) > 1').pluck(:number)
      authorizations = Spree::ReturnAuthorization.where(number: numbers)

      authorizations.find_each do |authorization|
        authorization.number = authorization.class.number_generator.method(:generate_permalink).call(authorization.class)
        authorization.save
      end

      remove_index :spree_return_authorizations, :number if index_exists?(:spree_return_authorizations, :number)
      add_index :spree_return_authorizations, :number, unique: true
    end
  end
end
