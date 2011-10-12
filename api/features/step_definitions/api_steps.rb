World(Rack::Test::Methods)

Given /^I am a valid API user$/ do
  @user = Factory(:user)
  unless admin_role = Spree::Role.find_by_name('admin')
    admin_role = Spree::Role.create(:name => 'admin')
  end

  unless @user.roles(&:name).include?('admin')
    @user.roles << admin_role
  end

  authorize @user.authentication_token, "X"
end

Given /^I send and accept json$/ do
  header "Content-Type","application/json"
  header "Accept","application/json"
end
