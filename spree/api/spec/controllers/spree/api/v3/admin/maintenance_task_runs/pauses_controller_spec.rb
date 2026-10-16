require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MaintenanceTaskRuns::PausesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:run) { create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::UpgradeStep', status: 'running') }

  describe 'POST #create' do
    it 'asks the runner to stop' do
      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('pausing')
      expect(run.reload).to be_pausing
    end

    it 'refuses to pause a finished run' do
      run.update!(status: 'succeeded')

      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'with read access only' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permissions) { %w[read_maintenance_tasks] }

    it 'cannot pause a run' do
      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:forbidden)
      expect(run.reload).to be_running
    end
  end
end
