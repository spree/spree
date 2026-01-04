class CreateSpreeWorkflowTables < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_workflow_executions do |t|
      t.string :workflow_id, null: false
      t.string :transaction_id, null: false
      t.string :status, null: false
      t.string :current_step_id

      t.json :input
      t.json :output
      t.json :context

      t.text :error_message
      t.string :error_class

      t.references :store, index: true

      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :spree_workflow_executions, :workflow_id
    add_index :spree_workflow_executions, :transaction_id, unique: true
    add_index :spree_workflow_executions, :status
    add_index :spree_workflow_executions, [:workflow_id, :status]

    create_table :spree_workflow_step_executions do |t|
      t.references :workflow_execution, null: false, index: true
      t.string :step_id, null: false
      t.string :status, null: false
      t.integer :position, null: false

      t.json :input
      t.json :output
      t.json :compensation_data

      t.integer :attempts, null: false, default: 0
      t.text :error_message
      t.string :error_class

      t.boolean :async, null: false, default: false

      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :spree_workflow_step_executions, :step_id
    add_index :spree_workflow_step_executions, :status
    add_index :spree_workflow_step_executions, [:workflow_execution_id, :step_id],
              unique: true, name: 'index_workflow_step_executions_on_execution_and_step'
    add_index :spree_workflow_step_executions, [:workflow_execution_id, :position],
              name: 'index_workflow_step_executions_on_execution_and_position'
  end
end
