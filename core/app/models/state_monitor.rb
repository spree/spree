class StateMonitor < ActiveModel::Observer
  observe :order, :shipment

  # Generic transition callback *after* the transition is performed
  def after_transition(object, transition)

     if User.current
       author = User.current
     elsif object.respond_to?(:user)
       author = object.user
     end

     object.state_events.create({
       :previous_state => transition.attributes[:from],
       :next_state     => transition.attributes[:to],
       :name           => transition.attributes[:event].to_s,
       :user_id        => author && author.id
       })

     ActiveRecord::Base.logger.info("#{object.class}##{object.id}: #{transition.attributes[:from]} => #{transition.attributes[:to]}")
  end

end