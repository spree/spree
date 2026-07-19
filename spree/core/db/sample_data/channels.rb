# Adds two extra channels alongside the seeded 'Online Store' so sample data
# exercises the channel-aware code paths (publishing, channel filters,
# channel-scoped order attribution).
store = Spree::Store.default

store.channels.find_or_create_by!(code: 'pos') do |channel|
  channel.name = 'Point of Sale'
end

# Normally seeded by Spree::Seeds::Channels; created here too so installs
# seeded before the gated-wholesale seed existed still get the channel, and
# upgraded with the gated posture when it's missing.
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
