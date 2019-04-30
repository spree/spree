require 'spec_helper'

describe Spree::Admin::ReportsController, type: :controller do
  stub_authorization!

  after do
    Spree::Admin::ReportsController.available_reports.delete_if do |key, _value|
      key != :sales_total
    end
  end

  describe 'ReportsController.available_reports' do
    it 'contains sales_total' do
      expect(Spree::Admin::ReportsController.available_reports.key?(:sales_total)).to be true
    end

    it 'has the proper sales total report description' do
      expect(Spree::Admin::ReportsController.available_reports[:sales_total][:description]).to eql('Sales Total For All Orders')
    end
  end

  describe 'ReportsController.add_available_report!' do
    context 'when adding the report name' do
      it 'contains the report' do
        Spree::Admin::ReportsController.add_available_report!(:some_report)
        expect(Spree::Admin::ReportsController.available_reports.key?(:some_report)).to be true
      end
    end
  end

  describe 'GET index' do
    it 'is ok' do
      get :index
      expect(response).to be_ok
    end
  end

  it 'responds to model_class as Spree::AdminReportsController' do
    expect(controller.send(:model_class)).to eql(Spree::Admin::ReportsController)
  end
end
