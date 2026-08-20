class CreateSpreeAssistantTables < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_assistant_chats do |t|
      t.references :store, null: false, index: true
      t.references :admin_user, null: false, index: true
      t.string :title
      t.string :provider
      t.string :model_id
      t.timestamps
    end

    create_table :spree_assistant_messages do |t|
      t.references :chat, null: false, index: true
      # Parent tool call for a tool-result message. The column MUST be named
      # `tool_call_id` — the persistence layer assigns it by that name.
      t.references :tool_call, index: true
      t.string :role, null: false
      t.text :content
      t.integer :input_tokens
      t.integer :output_tokens
      t.timestamps
    end

    add_index :spree_assistant_messages, :role

    create_table :spree_assistant_tool_calls do |t|
      t.references :message, null: false, index: true
      t.string :tool_call_id, null: false
      t.string :name, null: false
      # Approval lifecycle: proposed | approved | rejected | executed | failed.
      # Reads never get a row here — only mutations are held for approval.
      t.string :status
      t.text :summary
      t.datetime :resolved_at
      t.references :resolved_by, index: true

      if t.respond_to?(:jsonb)
        t.jsonb :arguments, default: {}
        t.jsonb :result, default: {}
      else
        t.json :arguments, default: {}
        t.json :result, default: {}
      end

      t.timestamps
    end

    add_index :spree_assistant_tool_calls, :tool_call_id, unique: true
    add_index :spree_assistant_tool_calls, :name
  end
end
