require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MaintenanceTaskRuns::ResumptionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:run) do
    create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::UpgradeStep', status: 'paused', cursor: '42')
  end

  describe 'POST #create' do
    it 'enqueues the run again from its cursor' do
      expect { post :create, params: { maintenance_task_run_id: run.prefixed_id } }.
        to have_enqueued_job(Spree::MaintenanceTasks::RunJob)

      expect(response).to have_http_status(:ok)
      expect(run.reload).to be_enqueued
      expect(run.cursor).to eq('42')
    end

    it 'refuses to resume a cancelled run' do
      run.update!(status: 'cancelled')

      post :create, params: { maintenance_task_run_id: run.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
