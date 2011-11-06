class Order < ActiveRecord::Base; end;

class PreventNilEmail < ActiveRecord::Migration
  def self.up
    Order.where(:email => nil).update_all(:email => 'guest@example.com')
    Order.where(:email => '').update_all(:email => 'guest@example.com')
  end

  def self.down
  end
end
