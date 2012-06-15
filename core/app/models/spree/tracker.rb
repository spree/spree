module Spree
  class Tracker < ActiveRecord::Base
    attr_accessible :analytics_id, :environment, :active

    def self.current
      where(:active => true, :environment => Rails.env).first
    end
  end
end
