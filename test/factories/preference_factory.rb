Factory.define :preference do |f|
  f.owner { |r| User.find(:first) || r.association(:user) }
  f.attribute "notifications"
  f.value false
end
