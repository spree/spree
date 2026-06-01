# Adds two extra channels alongside the seeded 'Online Store' so sample data
# exercises the channel-aware code paths (publishing, channel filters,
# channel-scoped order attribution).
store = Spree::Store.default

store.channels.find_or_create_by!(code: 'pos') do |channel|
  channel.name = 'Point of Sale'
end

store.channels.find_or_create_by!(code: 'wholesale') do |channel|
  channel.name = 'Wholesale'
end
