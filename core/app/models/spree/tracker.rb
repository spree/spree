module Spree
  class Tracker < Spree::Base
    before_save :clear_cache

    def self.current
      tracker = Rails.cache.fetch("current_tracker") do
        where(active: true).first
      end
      tracker.analytics_id.present? ? tracker : nil if tracker
    end


    def clear_cache
      Rails.cache.delete("current_tracker")
    end
  end
end
