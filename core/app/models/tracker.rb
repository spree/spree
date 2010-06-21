class Tracker < ActiveRecord::Base
  def self.current
    Tracker.find(:first, :conditions => {:active => true, :environment => ENV['RAILS_ENV']})   
  end
end
