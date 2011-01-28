require 'factory_girl'

Factory.sequence :email do |n|
  "somebody#{n}@example.com"
end

Factory.sequence :user_authentication_token do |n|
  "xxxx#{Time.now.to_i}#{rand(1000)}#{n}xxxxxxxxxxxxx"
end

Factory.define :user do |f|
  f.email { Factory.next(:email) }
  f.login { |u| u.email }
  f.authentication_token { Factory.next(:user_authentication_token) }
  f.password "secret"
  f.password_confirmation "secret"
end

FEATURES_PATH = File.expand_path('../..', __FILE__)

# load shared env with features
require File.expand_path('../../../../features/support/env', __FILE__)

