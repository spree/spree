module Spree
  class Tracker < Spree::Base
    after_commit :clear_cache

    validates :analytics_id, presence: true, uniqueness: { allow_blank: true }

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
