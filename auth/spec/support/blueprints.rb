require 'machinist/active_record'

User.blueprint do
  email { "email#{sn}@person.com"  }
end