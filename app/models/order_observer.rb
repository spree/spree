class OrderObserver < ActiveRecord::Observer
  observe :order

  # Generic transition callback *after* the transition is performed
  def after_transition(record, attribute_name, event_name, from_state, to_state)
    current_user_session = UserSession.activated? ? UserSession.find : nil
    author = current_user_session ? current_user_session.user : record.user
    record.state_events.create({
        :previous_state => from_state,
        :name           => event_name,
        :user_id        => author && author.id 
      })
    ActiveRecord::Base.logger.info("Order##{record.id}: #{from_state} => #{to_state}")
  end
end
