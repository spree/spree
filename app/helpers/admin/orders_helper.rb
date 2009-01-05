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
    @order_events.sort.each do |event| 
      links << (link_to event, fire_admin_order_url(@order, :e => event), {:method => :put, :confirm => "Are you sure you want to #{event}?"}) if @order.send("can_#{event}?")
    end
    return "" if links.empty?
    links.join(' &nbsp;')    
  end
  
  # Takes the OrderFilter and converts it into a hash of name/value pairs that can be used in query string
  def generate_search_options(filter)
    options = {}
    filter.attributes.each do |key, value|
      filter_key = "filter[#{key.to_s}]"
      options[filter_key] = value
    end
    options
  end
end
