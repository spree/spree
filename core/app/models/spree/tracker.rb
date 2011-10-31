class Spree::Tracker < ActiveRecord::Base
  def self.current
    where(:active => true, :environment => Rails.env).first
  end
end
