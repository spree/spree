require 'spec_helper'

describe Spree::StatesController do
  before(:each) do
    state = create(:state)
  end

  it 'should display state mapper' do
    spree_get :index, { :format => :js }
    assigns[:state_info].should_not be_empty
  end
end
