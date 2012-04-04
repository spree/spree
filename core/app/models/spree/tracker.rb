module Spree
  class Tracker < ActiveRecord::Base
    attr_accessible :analytics_id, :environment, :active

    def self.current
      first(:conditions => { :active => true, :environment => Rails.env })
    end
  end
end
