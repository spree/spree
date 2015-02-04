class MoveTrackerInformationToStore < ActiveRecord::Migration
  def up
    return if Spree::Tracker.current(deprecation_warning: false).nil? || begin
      Spree::Store.current.nil?
    rescue TypeError
      true
    end
    analytics_id = Spree::Tracker.current.analytics_id
    Spree::Store.current.set_preference :analytics_id, analytics_id
  end

  def down
    Spree::Store.current.set_preference :analytics_id, nil if Spree::Store.current
  rescue TypeError
  end
end
