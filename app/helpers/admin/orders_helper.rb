module Admin::OrdersHelper

  # Gets the list of available transitions for the specified state
  def available_events(order)
    #TODO - optimize this with some form of cacheing (should be a finite list that would only change after new code)
    state_machine = Order.state_machines['state']
    available = []
    events = state_machine.events.keys
    events.each do |event|
      state_machine.events[event].transitions.each do |transition|
        if transition.from_states.include?(order.state)
          available << (link_to event, transition_admin_order_url(order, :t => event), :method => :put)
          break
        end
      end
    end
    available
  end
  
  # Renders all the txn partials that may have been specified in the extensions
  def render_txn_partials(order)
    @txn_partials.inject("") do |extras, partial|
      extras += render :partial => partial, :locals => {:payment => order}
    end
  end
  
end
