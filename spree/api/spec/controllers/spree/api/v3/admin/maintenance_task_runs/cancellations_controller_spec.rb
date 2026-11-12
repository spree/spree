require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MaintenanceTaskRuns::CancellationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:run) { create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::UpgradeStep', status: 'running') }

  describe 'POST #create' do
    it 'asks the runner to stop for good' do
      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(run.reload).to be_cancelling
    end

    it '404s for a run that does not exist' do
      post :create, params: { maintenance_task_run_id: 'mtr_nonexistent' }

      expect(response).to have_http_status(:not_found)
    end
  end

  # Checked before anything else, so an admin is told the feature is off
  # rather than which permission they lack — no grant would help.
  context 'when the installation turns maintenance tasks off' do
    before { allow(Spree::Config).to receive(:maintenance_tasks_dashboard_enabled).and_return(false) }

    it 'refuses a signed-in admin and says why' do
      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['message']).to include('spree upgrade')
      expect(json_response['error']).not_to have_key('details')
      expect(run.reload).to be_running
    end
  end

  context 'without maintenance task access' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permissions) { %w[read_orders write_products] }

    it 'cannot cancel a run' do
      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(run.reload).to be_running
    end
  end

  context 'with write access' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permissions) { %w[write_maintenance_tasks] }

    it 'can cancel a run' do
      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(run.reload).to be_cancelling
    end
  end
end
