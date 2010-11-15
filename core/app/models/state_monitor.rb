class StateMonitor < ActiveRecord::Observer
  observe :order, :shipment

  # Generic transition callback *after* the transition is performed
  def after_transition(object, transition)

    # current_user_session = Session.activated? ? Session.find : nil
    #
    # if current_user_session
    #   author = current_user_session.user
    # elsif object.respond_to?(:user)
    #   author = object.user
    # end
    #
    # to_state = transition.attributes[:to_name]
    # object.state_events.create({
    #   :previous_state => transition.attributes[:from],
    #   :name           => transition.attributes[:event].to_s,
    #   :user_id        => author && author.id
    #   })
    #
    # ActiveRecord::Base.logger.info("#{object.class}##{object.id}: #{transition.attributes[:from]} => #{transition.attributes[:to]}")
  end

end
