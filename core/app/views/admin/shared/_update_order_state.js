$('#order_tab_summary h5#order_total').html('<%= "#{t('total')}: #{number_to_currency(@order.total)}" %>');
$('#order_tab_summary h5#order_status').html('<%= "#{t('status')}: #{t("order_state.#{@order.state}")}" %>');
$('#order_tab_summary h5#payment_status').html('<%= "#{t('payment')}: #{t("payment_states.#{@order.payment_state}")}" %>');
$('#order_tab_summary h5#shipment_status').html('<%= "#{t('shipment')}: #{t("shipment_states.#{@order.shipment_state}")}" %>');
