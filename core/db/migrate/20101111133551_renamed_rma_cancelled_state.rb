class RenamedRmaCancelledState < ActiveRecord::Migration
  class ReturnAuthorization < ActiveRecord::Base

  end

  def self.up
    ReturnAuthorization.where(:state => 'cancelled').each do |rma|
      rma.update_attribute_without_callbacks(:state, 'canceled')
    end
  end

  def self.down
  end
end
