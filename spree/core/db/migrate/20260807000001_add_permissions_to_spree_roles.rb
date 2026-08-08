class AddPermissionsToSpreeRoles < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_roles do |t|
      t.string :description
      t.boolean :mutable, default: true, null: false

      if t.respond_to?(:jsonb)
        t.jsonb :permissions
      else
        t.json :permissions
      end
    end
  end
end
