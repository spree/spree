class CreateSpreeMaintenanceTaskRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_maintenance_task_runs do |t|
      t.string :task_name, null: false
      t.string :status, null: false
      t.boolean :dry_run, null: false, default: false

      t.string :cursor
      t.integer :tick_count, null: false, default: 0
      t.integer :tick_total

      t.decimal :time_running, null: false, default: 0.0, precision: 12, scale: 3
      t.datetime :started_at
      t.datetime :ended_at

      t.string :error_class
      t.text :error_message
      t.text :error_backtrace

      t.string :job_id
      t.string :initiated_via, null: false

      t.references :parent_run, null: true
      t.references :store, null: true
      t.references :admin_user, null: true
      t.references :api_key, null: true

      if t.respond_to?(:jsonb)
        t.jsonb :arguments
        t.jsonb :tallies
        t.jsonb :metadata
      else
        t.json :arguments
        t.json :tallies
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_maintenance_task_runs, [:task_name, :status]
    add_index :spree_maintenance_task_runs, :created_at
  end
end
