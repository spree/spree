class AddQueuedMail < ActiveRecord::Migration
  def self.up
    create_table :queued_mails do |t|
      t.column :object,     :text
      t.column :mailer,     :string
    end
  end

  def self.down
    drop_table :queued_mails
  end
end
