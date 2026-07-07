class CreateSpreeOrderApprovals < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_order_approvals, if_not_exists: true do |t|
      t.references :order, null: false, index: false
      t.string :status, null: false
      t.string :level
      t.text :note
      t.references :approver, polymorphic: true, index: false
      t.datetime :decided_at
      if t.respond_to? :jsonb
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_order_approvals, [:order_id, :status], if_not_exists: true
    add_index :spree_order_approvals, [:approver_id, :approver_type],
              name: 'idx_order_approvals_approver', if_not_exists: true
  end
end
