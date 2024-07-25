class AddRefunderToSpreeRefunds < ActiveRecord::Migration[6.1]
  def change
    add_reference :spree_refunds, :refunder, index: true, if_not_exists: true
  end
end
