class Spree::Tracker < ActiveRecord::Base
  def self.current
    find(:first, :conditions => {:active => true, :environment => ENV['RAILS_ENV']})
  end
end
