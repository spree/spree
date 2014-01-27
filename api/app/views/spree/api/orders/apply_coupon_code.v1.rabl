object @coupon_result

# Mimic of eventual payload in Spree Core to keep contract the same when we upgrade.
# https://github.com/spree/spree/blob/master/api/app/views/spree/api/promotions/handler.v1.rabl
node(:success) { @coupon_result.success }
node(:error) { @coupon_result.error }
node(:successful) { @coupon_result.coupon_applied? }
