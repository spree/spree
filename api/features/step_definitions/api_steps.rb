World(Rack::Test::Methods)

Given /^I am a valid API user$/ do
  @user = Factory(:user)
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

