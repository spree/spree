World(Rack::Test::Methods)

#There are issues with how testing loads the Fabricators
#  This seems to init them without the Rails stack or before the Rails stack
Fabricator(:user) do
  email { Fabricate.sequence(:user_email) { |n| "user#{n}@example.org" } }
  login { |u| u.email }
  authentication_token { Fabricate.sequence(:user_authentication_token) { |n| "#{n}#{n}#{n}xxx#{n}#{n}#{n}xxx"}}
  password "secret"
  password_confirmation { |u| u.password }
  #after_create { |user| user.roles << Fabricate(:role) }
end

Fabricator(:role) do
  name "admin"
end

Fabricator(:order) do
  number { Fabricate.sequence(:order_number) { |n| "R#{n}" } }
  email { Fabricate.sequence(:order_email) { |n| "user#{n}@example.com" } }
end

Given /^I am a valid API user$/ do
  @user = Fabricate(:user)
  unless admin_role = Role.find_by_name('admin')
    admin_role = Role.create(:name => 'admin')
  end

  unless @user.roles(&:name).include?('admin')
    @user.roles << admin_role
  end

  authorize @user.authentication_token, "X"
end

Given /^I send and accept json$/ do
  #header 'AUTHORIZATION', "#{@user.authentication_token}:X"
  header "Content-Type","application/json"
  header "Accept","application/json"
end

private

def encode_credentials(username, password)
  req = Net::HTTP::Get.new('/api/orders/8567520/shipments')
  req.basic_auth(@user.authentication_token,"x")
  return req['authorization'].gsub(/Basic\w/, "")
  #ActionController::HttpAuthentication::Basic.encode_credentials(username,password)
  #{}"Basic " + Base64.encode64("#{username}:#{password}").gsub(/\r\n/m, "")
end

