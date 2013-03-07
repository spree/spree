$('#order_tab_summary #order_status').html('<%= j t(@order.state, :scope => :order_state) %>');
$('#order_tab_summary #order_total').html('<%= j @order.display_total.to_html %>');

<% if @order.completed? %>
  $('#order_tab_summary #payment_status').html('<%= j t(@order.payment_state, :scope => :payment_states, :default => [:missing, "none"]) %>');
  $('#order_tab_summary #shipment_status').html('<%= j t(@order.shipment_state, :scope => :shipment_state, :default => [:missing, "none"]) %>');
<% end %>
