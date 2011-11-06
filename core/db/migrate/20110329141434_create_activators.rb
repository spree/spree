class CreateActivators < ActiveRecord::Migration
  def change
    create_table :activators, :force => true do |t|
      t.string   :description
      t.datetime :expires_at
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :starts_at
      t.string   :name
      t.string   :event_name
      t.string   :type
    end
  end
end
