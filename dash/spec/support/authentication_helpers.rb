module AuthenticationHelpers
  def sign_in_as!(user)
    visit '/login'
    fill_in 'Email', :with => user.email
    fill_in 'Password', :with => 'secret'
    click_button 'Log In'
  end

end

RSpec.configure do |c|
  c.include AuthenticationHelpers, :type => :request
end
