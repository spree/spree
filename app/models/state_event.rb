class StateEvent < ActiveRecord::Base
  belongs_to :user
  belongs_to :order
  
  def <=>(other)
    created_at <=> other.created_at
  end

  def before_create
    if current_user_session = UserSession.find
      self.user_id ||= current_user_session.user.id
    end
  end
end
