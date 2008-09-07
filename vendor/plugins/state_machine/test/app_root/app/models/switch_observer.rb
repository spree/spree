class SwitchObserver < ActiveRecord::Observer
  cattr_accessor :notifications
  self.notifications = []
  
  def before_turn_on(switch, from_state, to_state)
    notifications << ['before_turn_on', switch, from_state, to_state]
  end
  
  def after_turn_on(switch, from_state, to_state)
    notifications << ['after_turn_on', switch, from_state, to_state]
  end
  
  def before_transition(switch, attribute, event, from_state, to_state)
    notifications << ['before_transition', switch, attribute, event, from_state, to_state]
  end
  
  def after_transition(switch, attribute, event, from_state, to_state)
    notifications << ['after_transition', switch, attribute, event, from_state, to_state]
  end
end
