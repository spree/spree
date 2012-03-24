require 'spec_helper'

describe Spree::StatesController do
  before(:each) do
    state = Factory(:state)
  end

  it 'should display state mapper' do
    get :index, { :format => :js }
    assigns[:state_info].should_not be_empty
  end
end
