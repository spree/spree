Factory.sequence(:role_sequence) {|n| "Role ##{n}"}

Factory.define(:role) do |record|
  record.name { Factory.next(:role_sequence) } 
end