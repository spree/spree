class OrderObserver < ActiveRecord::Observer
  observe :order

  # Generic transition callback *after* the transition is performed
  def after_transition(order, transition)
    current_user_session = UserSession.activated? ? UserSession.find : nil
    author = current_user_session ? current_user_session.user : order.user
    to_state = transition.attributes[:to_name]
    order.state_events.create({
        :previous_state => transition.attributes[:from],
        :name           => transition.attributes[:event].to_s,
        :user_id        => author && author.id 
      })
    ActiveRecord::Base.logger.info("Order##{order.id}: #{transition.attributes[:from]} => #{transition.attributes[:to]}")
  end

end
