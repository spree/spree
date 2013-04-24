require 'spec_helper'

describe Spree::Admin::ReportsController do

  it 'should respond to model_class as Spree::AdminReportsController' do
    controller.send(:model_class).should eql(Spree::Admin::ReportsController)
  end

end
