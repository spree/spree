require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::UpgradeStepsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the manifest steps in the order they must run' do
      get :index

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |step| step['id'] }

      expect(ids).to include('migrate_capture_methods')
      # Rich text is copied onto rows the customer migration creates, so the
      # order the endpoint returns is the order they have to run in.
      expect(ids.index('migrate_rich_text_to_columns')).to be > ids.index('migrate_users_to_customers')
    end

    it 'names the task each step runs' do
      get :index

      step = json_response['data'].find { |entry| entry['id'] == 'migrate_capture_methods' }

      expect(step['task_name']).to eq('Spree::MaintenanceTasks::Upgrade::CaptureMethods')
      expect(step['arguments']).to eq({})
    end

    # A rake-backed step of a released manifest runs inside the generic
    # wrapper, so the step id has to travel as an argument.
    it 'carries the step id for wrapper-backed steps' do
      get :index

      wrapper = json_response['data'].find do |entry|
        entry['task_name'] == 'Spree::MaintenanceTasks::UpgradeStep'
      end

      expect(wrapper['arguments']['step_id']).to eq(wrapper['id'])
    end

    it 'includes the operator notes the manifest carries' do
      get :index

      step = json_response['data'].find { |entry| entry['id'] == 'migrate_capture_methods' }

      expect(step['notes']).to be_present
    end

    it 'reports how each step last went' do
      run = create(:maintenance_task_run,
                   task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods',
                   status: 'succeeded')

      get :index

      step = json_response['data'].find { |entry| entry['id'] == 'migrate_capture_methods' }

      expect(step['last_run']['id']).to eq(run.prefixed_id)
      expect(step['last_run']['status']).to eq('succeeded')
    end

    it 'reports no run for a step that has never been run' do
      get :index

      step = json_response['data'].find { |entry| entry['id'] == 'migrate_capture_methods' }

      expect(step['last_run']).to be_nil
    end

    # Wrapper runs all share one task name, so the step id is what tells one
    # step's history from another's.
    it 'matches a wrapper run to the step it ran' do
      create(:maintenance_task_run,
             task_name: 'Spree::MaintenanceTasks::UpgradeStep',
             arguments: { 'step_id' => 'taxon_store_id' },
             status: 'succeeded')

      get :index

      taxon_step = json_response['data'].find { |entry| entry['id'] == 'taxon_store_id' }
      other_step = json_response['data'].find do |entry|
        entry['task_name'] == 'Spree::MaintenanceTasks::UpgradeStep' && entry['id'] != 'taxon_store_id'
      end

      expect(taxon_step['last_run']).to be_present
      expect(other_step['last_run']).to be_nil
    end
  end

  describe 'authorization' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permissions) { %w[read_orders] }

    it 'refuses a caller without the maintenance tasks grant' do
      request.headers.merge!(headers)

      get :index

      expect(response).to have_http_status(:forbidden)
    end
  end
end
