# Tableless model based on a forum post by Rick Olson
class InventoryLevel < ActiveRecord::Base
  #Inventory level does not need to be stored in the database so these two methods will spoof the column stuff
  def self.columns() @columns ||= []; end
  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end
  
  #column :current, :integer
  column :adjustment, :integer
  column :on_hand, :integer
  
  #validates_numericality_of :adjustment, :only_integer => true
  #def validate
    # to do perform validation
    #errors.add(:start, "Must specify a start date") and return if start.blank? and not stop.blank?
    #throw "Invalid Inventory Quantity"
  #end
end