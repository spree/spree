class GoogleAnalytic < ActiveRecord::Base
  validates_presence_of :analytics_id
  validates_uniqueness_of :analytics_id
  validate :validate_one_active_account
protected
  def validate_one_active_account
    errors.add(:is_active, 'can only be true for one account.') if is_active &&
      !GoogleAnalytic.find(:first, :conditions => { :is_active => 't' }).nil?
  end
end
