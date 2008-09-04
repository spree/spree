module Admin::OrdersHelper

  AVAILABLE_OPERATIONS = {
    :abandoned => [:delete],
    :incomplete => [:delete],
    :authorized => [:capture, :ship, :cancel],
    :captured => [:ship, :cancel],
    :canceled => [],
    :returned => [],
    :shipped => [:return, :cancel],
    :paid => [:ship, :cancel],
    :pending_payment => [:cancel]
  }

  # return the list of possible actions for the order based on its current state
  def action_links(order)
    state = Order::Status.from_value(order.status)
    return [] if state.nil?
    state = state.gsub(' ', '_').downcase.to_sym
    AVAILABLE_OPERATIONS[state]
  end
  
  # Renders all the txn partials that may have been specified in the extensions
  def render_txn_partials(order)
    @txn_partials.inject("") do |extras, partial|
      extras += render :partial => partial, :locals => {:payment => order}
    end
  end
  
end
