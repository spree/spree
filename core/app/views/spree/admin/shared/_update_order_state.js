$('#order_tab_summary h5#order_status').html('<%= j t(:status) %>: <%= j t(@order.state, :scope => :order_state) %>');
$('#order_tab_summary h5#order_total').html('<%= j t(:total) %>: <%= j @order.display_total %>');

<% if @order.completed? %>
  $('#order_tab_summary h5#payment_status').html('<%= j t(:payment) %>: <%= j t(@order.payment_state, :scope => :payment_states, :default => [:missing, "none"]) %>');
  $('#order_tab_summary h5#shipment_status').html('<%= j t(:shipment) %>: <%= j t(@order.shipment_state, :scope => :shipment_state, :default => [:missing, "none"]) %>');
<% end %>
