class MoveTrackerInformationToStore < ActiveRecord::Migration
  def up
    analytics_id = Spree::Tracker.current.try(:analytics_id)
    Spree::Store.set_preference :tracker, analytics_id
  end

  def down
    Spree::Store.set_preference :tracker, nil
  end
end
