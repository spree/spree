module Admin::OrdersHelper

  # Gets the list of available transitions for the specified state
  def available_events(order)
    #TODO - optimize this with some form of cacheing (should be a finite list that would only change after new code)
    state_machine = Order.state_machines['state']
    available = []
    events = state_machine.events.keys
    events.each do |event|
      available << (link_to event, fire_admin_order_url(order, :e => event), :method => :put) if order.send("can_#{event}?")
    end
    return "" if available.empty?
    available.join(' &nbsp;')
  end
  
  # Renders all the txn partials that may have been specified in the extensions
  def render_txn_partials(order)
    @txn_partials.inject("") do |extras, partial|
      extras += render :partial => partial, :locals => {:payment => order}
    end
  end
  
end
