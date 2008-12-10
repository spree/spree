module Admin::OrdersHelper
  
  # Renders all the txn partials that may have been specified in the extensions
  def render_txn_partials(order)
    @txn_partials.inject("") do |extras, partial|
      extras += render :partial => partial, :locals => {:payment => order}
    end
  end
  
  # Renders all the extension partials that may have been specified in the extensions
  def event_links
    links = []
    @order_events.each do |event| 
      links << (link_to event, fire_admin_order_url(@order, :e => event), :method => :put) if @order.send("can_#{event}?")
    end
    return "" if links.empty?
    links.join(' &nbsp;')    
  end
  
end
