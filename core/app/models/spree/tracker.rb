module Spree
  class Tracker < ActiveRecord::Base
    attr_accessible :analytics_id, :environment, :active

    def self.current
      tracker = where(:active => true, :environment => Rails.env).first
      tracker.analytics_id.present? ? tracker : nil if tracker
    end
  end
end
