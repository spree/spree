Factory.define :activator do |f|
  f.name 'Activator name'
  f.event_name 'spree.order.contents_changed'
  f.starts_at 2.weeks.ago
  f.expires_at 2.weeks.from_now
end
