class GoogleAnalytic < ActiveRecord::Base
  validates_presence_of :analytics_id
  validates_uniqueness_of :analytics_id
end
