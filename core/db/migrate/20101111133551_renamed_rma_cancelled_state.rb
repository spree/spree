class RenamedRmaCancelledState < ActiveRecord::Migration
  def up
    execute "UPDATE return_authorizations SET state = 'canceled' WHERE state = 'cancelled'"
  end

  def down
    execute "UPDATE return_authorizations SET state = 'cancelled' WHERE state = 'canceled'"
  end
end
