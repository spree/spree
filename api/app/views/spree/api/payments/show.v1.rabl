object @payment
attributes *payment_attributes
node(:display_amount) { @payment.display_amount.to_s }
