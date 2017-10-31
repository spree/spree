class RemoveEnvironmentFromTracker < ActiveRecord::Migration[4.2]
  class Spree::Tracker < Spree::Base; end

  def up
    Spree::Tracker.where('environment != ?', Rails.env).update_all(active: false)
    remove_column :spree_trackers, :environment
  end
end
