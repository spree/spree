# frozen_string_literal: true

class CreateEventStoreEvents < ActiveRecord::Migration[4.2]
  def change
    create_table(:event_store_events_in_streams, id: :bigserial, force: false) do |t|
      t.string      :stream,      null: false
      t.integer     :position,    null: true
      t.references  :event,       null: false, type: :uuid
      t.datetime    :created_at,  null: false
    end
    add_index :event_store_events_in_streams, [:stream, :position], unique: true
    add_index :event_store_events_in_streams, [:created_at]
    add_index :event_store_events_in_streams, [:stream, :event_id], unique: true

    create_table(:event_store_events, id: :bigserial, force: false) do |t|
      t.references  :event,       null: false, type: :uuid
      t.string      :event_type,  null: false
      t.binary      :metadata
      t.binary      :data, null: false
      t.datetime    :created_at,  null: false
      t.datetime    :valid_at,    null: true
    end
    add_index :event_store_events, :event_id, unique: true
    add_index :event_store_events, :created_at
    add_index :event_store_events, :valid_at
    add_index :event_store_events, :event_type
  end
end
