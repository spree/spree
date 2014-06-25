require 'spec_helper'

describe Spree::Admin::ReportsController do
  stub_authorization!

  describe 'ReportsController.available_reports' do
    it 'should contain sales_total' do
      Spree::Admin::ReportsController.available_reports.keys.include?(:sales_total).should be_true
    end

    it 'should have the proper sales total report description' do
      Spree::Admin::ReportsController.available_reports[:sales_total][:description].should eql('Sales Total For All Orders')
    end

  end

  describe 'ReportsController.add_available_report!' do
    context 'when adding the report name' do
      it 'should contain the report' do
        Spree::Admin::ReportsController.add_available_report!(:some_report)
        Spree::Admin::ReportsController.available_reports.keys.include?(:some_report).should be_true
      end
    end
  end

  describe 'GET index' do
    it 'should be ok' do
      spree_get :index
      response.should be_ok
    end
  end

  it 'should respond to model_class as Spree::AdminReportsController' do
    controller.send(:model_class).should eql(Spree::Admin::ReportsController)
  end

  after(:each) do
    Spree::Admin::ReportsController.available_reports.delete_if do |key, value|
      key != :sales_total
    end
  end
end
