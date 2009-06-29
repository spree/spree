class UpdateCountryRenameName < ActiveRecord::Migration
  def self.up
    change_table :countries do |t|
      t.rename :name, :iso_name
      t.rename :printable_name, :name
    end    

    begin
      Country.update(119, { :name => 'Macedonia' })
      Country.update(197, { :name => 'Taiwan' })
      Country.update(105, { :name => 'North Korea' })
      Country.update(106, { :name => 'South Korea' })
    rescue Exception
    end
  end

  def self.down
    change_table :countries do |t|
      t.rename :name, :printable_name    
      t.rename :iso_name, :name
    end
  end
end
