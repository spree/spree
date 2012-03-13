class Tracker < ActiveRecord::Base
  def self.current
    Tracker.find(:first, :conditions => {:active => true, :environment => Rails.env})
  end
end
