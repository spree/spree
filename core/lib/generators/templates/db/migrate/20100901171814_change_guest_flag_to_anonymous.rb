class ChangeGuestFlagToAnonymous < ActiveRecord::Migration
  def self.up
    change_table :users do |t|
      t.rename :guest, :anonymous
    end
  end

  def self.down
    change_table :users do |t|
      t.rename :anonymous, :guest
    end
  end
end
