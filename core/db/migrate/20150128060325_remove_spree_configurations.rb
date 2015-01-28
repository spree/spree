class RemoveSpreeConfigurations < ActiveRecord::Migration
  def up
    drop_table "spree_configurations"
  end

  def down
    create_table "spree_configurations", force: true do |t|
      t.string   "name"
      t.string   "type",       limit: 50
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "spree_configurations", ["name", "type"], name: "index_spree_configurations_on_name_and_type"
  end
end
