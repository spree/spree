class ReturnAuthorization < ActiveRecord::Base; end;

class RenamedRmaCancelledState < ActiveRecord::Migration
  def up
    ReturnAuthorization.where(:state => 'cancelled').each do |rma|
      rma.update_attribute_without_callbacks(:state, 'canceled')
    end
  end

  def down
    raise IrreversibleMigration
  end
end
