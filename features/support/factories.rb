Factory.define :user do |u|
  u.sequence(:email) { |i| 'email_%d@email.com' % i }
  u.password              { 'password' }
  u.password_confirmation { 'password' }
end

Factory.define :admin_user, :parent => :user do |u|
  u.roles { [Factory(:role, :name => 'admin')] }
end

#Factory.define :anonymous_user, :class => :user do |u|
  #u.sequence(:email) { |i| 'token_%d@example.net' % i }
  #u.sequence(:token) { |i| 'token_%d' % i }
#end

Factory.define :role do |r|
end
