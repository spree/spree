module Admin::OrdersHelper

  # return the list of possible actions for the order based on its current state
  def action_links(order)
    state = Order::Status.from_value(order.status)
    return [] if state.nil?
    state = state.gsub(' ', '_').downcase.to_sym
    AVAILABLE_OPERATIONS[state]
  end
  
end
