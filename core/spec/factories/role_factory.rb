Factory.sequence(:role_sequence) {|n| "Role ##{n}"}

Factory.define(:role) do |record|
  record.name { Factory.next(:role_sequence) }
end

Factory.define(:admin_role, :parent => :role) do |r|
  r.name "admin"
end
