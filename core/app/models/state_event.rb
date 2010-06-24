class StateEvent < ActiveRecord::Base
  belongs_to :user
  belongs_to :stateful, :polymorphic => true
  before_create :assign_user

  def <=>(other)
    created_at <=> other.created_at
  end

  def assign_user
    if UserSession.activated? && current_user_session = UserSession.find
      self.user_id ||= current_user_session.user.id
    end
    true   # don't stop the filters
  end
end
