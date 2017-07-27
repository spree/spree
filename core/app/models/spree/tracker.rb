module Spree
  class Tracker < Spree::Base
    TRACKER_ENGINES = %i(google_analytics segment).freeze
    enum engine: TRACKER_ENGINES

    after_commit :clear_cache

    validates :analytics_id, presence: true, uniqueness: { scope: :engine, case_sensitive: false }

    scope :active, -> { where(active: true) }

    def self.current(engine = :google_analytics)
      tracker = Rails.cache.fetch("current_tracker/#{engine}") do
        send(engine).active.first
      end
      tracker&.analytics_id? ? tracker : nil
    end

    def clear_cache
      TRACKER_ENGINES.each do |engine|
        Rails.cache.delete("current_tracker/#{engine}")
      end
    end
  end
end
