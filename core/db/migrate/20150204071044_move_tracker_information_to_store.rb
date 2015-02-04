class MoveTrackerInformationToStore < ActiveRecord::Migration
  def up
    return if Spree::Tracker.current.nil? || begin
      Spree::Store.current.nil?
    rescue TypeError
      true
    end
    analytics_id = Spree::Tracker.current.analytics_id
    Spree::Store.current.set_preference :tracker, analytics_id
  end

  def down
    Spree::Store.current.set_preference :tracker, nil if Spree::Store.current
  rescue TypeError
  end
end
