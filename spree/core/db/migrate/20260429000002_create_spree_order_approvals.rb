class CreateSpreeOrderApprovals < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_order_approvals do |t|
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

    add_index :spree_order_approvals, [:order_id, :status]
    add_index :spree_order_approvals, [:approver_id, :approver_type],
              name: 'idx_order_approvals_approver'
  end
end
