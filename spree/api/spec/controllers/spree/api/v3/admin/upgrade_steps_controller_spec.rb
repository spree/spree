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
      # Reachable only from a store still below the released boundary.
      Spree::UpgradeRecord.stamp!('5.5', source: 'manual')

      get :index

      wrapper = json_response['data'].find do |entry|
        entry['task_name'] == 'Spree::MaintenanceTasks::UpgradeStep' && !entry['superseded']
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
      Spree::UpgradeRecord.stamp!('5.5', source: 'manual')
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

  describe 'which steps an installation is shown' do
    # The list would otherwise grow with every release Spree ships, and a
    # store that upgraded last release would be offered steps it must never
    # run again.
    # Earlier releases stay visible as history — a store should be able to see
    # which upgrades it has been through — but are never runnable.
    it 'marks the boundaries it has already crossed as superseded' do
      Spree::UpgradeRecord.stamp!('5.6', source: 'walk')

      get :index

      outstanding = json_response['data'].reject { |step| step['superseded'] }
      history = json_response['data'].select { |step| step['superseded'] }

      expect(outstanding.map { |step| step['from'] }.uniq).to eq(['5.6'])
      expect(history).not_to be_empty
      expect(history.map { |step| step['from'] }.uniq).not_to include('5.6')
    end

    it 'reports the boundary it is counting from' do
      Spree::UpgradeRecord.stamp!('5.6', source: 'walk')

      get :index

      expect(json_response['meta']['completed_version']).to eq('5.6')
      expect(json_response['meta']['completed_version_recorded']).to be(true)
      expect(json_response['meta']['superseded_step_count']).to be > 0
    end

    # A store installed fresh at this release has no upgrade at all — not the
    # outstanding steps, and not a history of releases it was never on.
    it 'shows a freshly installed store no upgrade whatsoever' do
      Spree::Upgrade.manifests.each { |m| Spree::UpgradeRecord.stamp!(m['to'], source: 'install') }

      get :index

      expect(json_response['data']).to be_empty
      expect(json_response['meta']['upgrade_relevant']).to be(false)
    end

    # An upgraded store keeps its history, so it can see which releases it has
    # been through even once nothing is outstanding.
    it 'keeps the history of a store that was upgraded' do
      Spree::Upgrade.manifests.each { |m| Spree::UpgradeRecord.stamp!(m['to'], source: 'walk') }

      get :index

      expect(json_response['data']).not_to be_empty
      expect(json_response['data']).to all(include('superseded' => true))
      expect(json_response['meta']['upgrade_relevant']).to be(true)
    end

    # Without a stamp the boundary is a guess, and saying so is what lets the
    # dashboard offer the older steps rather than silently hide them from a
    # store that has been postponing its upgrade.
    it 'admits when the boundary was assumed rather than recorded' do
      get :index

      expect(json_response['meta']['completed_version_recorded']).to be(false)
      expect(json_response['meta']['completed_version']).to eq('5.6')
    end

    it 'still bounds outstanding work at the installed version' do
      get :index

      outstanding = json_response['data'].reject { |step| step['superseded'] }

      expect(outstanding.map { |step| step['to'] }.uniq).to eq(['6.0'])
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
