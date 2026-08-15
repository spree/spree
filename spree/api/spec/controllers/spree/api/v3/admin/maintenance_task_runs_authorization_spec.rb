require 'spec_helper'

# Maintenance tasks can rewrite any data in the install, so the grant sits with
# the other sensitive access keys rather than under settings: out of the box
# only the admin role holds it (docs/plans/6.0-maintenance-tasks.md).
RSpec.describe Spree::Api::V3::Admin::MaintenanceTaskRunsController, type: :controller do
  render_views

  include_context 'API v3 Admin with custom permissions'

  before { request.headers.merge!(headers) }

  let(:task_class) do
    Class.new(Spree::MaintenanceTask) do
      def self.name = 'TestMaintenance::Authorized'
      def collection = Spree::Product.order(:id)
      def process(product) = nil
    end
  end

  let!(:run) { create(:maintenance_task_run, task_name: 'TestMaintenance::Authorized', status: 'running') }

  before do
    stub_const('TestMaintenance::Authorized', task_class)
    Spree.maintenance_tasks << 'TestMaintenance::Authorized'
  end

  after { Spree.maintenance_tasks.delete('TestMaintenance::Authorized') }

  context 'a role with no maintenance-task permission' do
    let(:custom_permissions) { %w[read_orders write_products] }

    it 'cannot list runs' do
      get :index

      expect(response).to have_http_status(:forbidden)
    end

    # The point of the separate key: broad data permissions elsewhere must not
    # add up to permission to run bulk rewrites.
    it 'cannot start a run' do
      post :create, params: { task_name: 'TestMaintenance::Authorized' }

      expect(response).to have_http_status(:forbidden)
      expect(Spree::MaintenanceTaskRun.where(status: 'enqueued')).to be_empty
    end

    it 'cannot cancel a run' do
      patch :cancel, params: { id: run.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(run.reload).to be_running
    end
  end

  context 'a role granted read access only' do
    let(:custom_permissions) { %w[read_maintenance_tasks] }

    it 'can review the run history' do
      get :index

      expect(response).to have_http_status(:ok)
    end

    it 'cannot start a run' do
      post :create, params: { task_name: 'TestMaintenance::Authorized' }

      expect(response).to have_http_status(:forbidden)
    end

    it 'cannot pause a run' do
      patch :pause, params: { id: run.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(run.reload).to be_running
    end

    # A backtrace names internal paths and class names — detail that belongs
    # to whoever may act on the run, not to everyone who may read it.
    it 'does not see error backtraces' do
      run.update!(status: 'errored', error_class: 'ArgumentError',
                  error_message: 'boom', error_backtrace: "app/models/secret.rb:42")

      get :show, params: { id: run.prefixed_id }

      expect(json_response['error_message']).to eq('boom')
      expect(json_response['error_backtrace']).to be_nil
    end
  end

  context 'a role granted write access' do
    let(:custom_permissions) { %w[write_maintenance_tasks] }

    it 'can start a run' do
      # Nothing may be in flight: one run per task is the rule.
      run.update!(status: 'succeeded')

      post :create, params: { task_name: 'TestMaintenance::Authorized' }

      expect(response).to have_http_status(:created)
    end

    it 'can cancel a run' do
      patch :cancel, params: { id: run.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(run.reload).to be_cancelling
    end

    it 'sees error backtraces' do
      run.update!(status: 'errored', error_class: 'ArgumentError',
                  error_message: 'boom', error_backtrace: "app/models/secret.rb:42")

      get :show, params: { id: run.prefixed_id }

      expect(json_response['error_backtrace']).to include('secret.rb')
    end
  end
end
