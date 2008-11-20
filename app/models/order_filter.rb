# Tableless model based on a forum post by Rick Olson
class OrderFilter < ActiveRecord::Base
  #Search criteria does not need to be stored in the database so these two methods will spoof the column stuff
  def self.columns() @columns ||= []; end
  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end
  
  column :start, :string
  column :stop, :string
  column :number, :string
  column :state, :string
  column :customer, :string
  column :checkout, :string
  
  def validate
    date_pattern = /^(0[1-9]|1[012])[\/][0-9]{2}[\/](19|20)[0-9]{2}$/
    errors.add(:start, "Must specify a start date") and return if start.blank? and not stop.blank?
    errors.add(:start, "Date must be formatted MM/DD/YYYY") unless start.blank? or date_pattern.match start.to_s
    errors.add(:stop, "Date must be formatted MM/DD/YYYY") unless stop.blank? or date_pattern.match stop.to_s
    unless stop.blank? 
      errors.add(:stop, "Stop date must be after start date") if DateTime.parse(stop) < DateTime.parse(start)  
    end
  end
  
end