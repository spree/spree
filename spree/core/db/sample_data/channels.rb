# Adds two extra channels alongside the seeded 'Online Store' so sample data
# exercises the channel-aware code paths (publishing, channel filters,
# channel-scoped order attribution).
store = Spree::Current.store

store.channels.find_or_create_by!(code: 'pos') do |channel|
  channel.name = 'Point of Sale'
end

# Normally created by the store defaults (@spree/config); created here too so
# a store provisioned before the gated wholesale channel existed still gets
# it, upgraded with the gated posture when it's missing.
wholesale = store.channels.find_or_create_by!(code: 'wholesale') do |channel|
  channel.name = 'Wholesale'
  channel.preferred_storefront_access = 'login_required'
  channel.preferred_guest_checkout = false
end

if wholesale.preferred_storefront_access.blank?
  wholesale.preferred_storefront_access = 'login_required'
  wholesale.preferred_guest_checkout = false
  wholesale.save!
end
