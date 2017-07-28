module Spree
  class Tracker < Spree::Base
    TRACKING_ENGINES = %i(google_analytics segment).freeze
    enum engine: TRACKING_ENGINES

    after_commit :clear_cache

    validates :analytics_id, presence: true, uniqueness: { scope: :engine, case_sensitive: false }

    scope :active, -> { where(active: true) }

    def self.current(engine = TRACKING_ENGINES.first)
      tracker = Rails.cache.fetch("current_tracker/#{engine}") do
        send(engine).active.first
      end
      tracker.analytics_id.present? ? tracker : nil if tracker
    end

    def clear_cache
      TRACKING_ENGINES.each do |engine|
        Rails.cache.delete("current_tracker/#{engine}")
      end
    end
  end
end
