require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MaintenanceTasksController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:task_class) do
    Class.new(Spree::MaintenanceTask) do
      def self.name = 'TestMaintenance::Backfill'
      description 'Backfill the thing'
      supports_dry_run
      attribute :label, :string
      attribute :mode, :string
      attribute :token, :string
      validates :label, presence: true
      validates :mode, inclusion: { in: %w[fast thorough] }
      mask_attribute :token
      def collection = Spree::Product.order(:id)
      def process(product) = nil
    end
  end

  before do
    stub_const('TestMaintenance::Backfill', task_class)
    Spree.maintenance_tasks << 'TestMaintenance::Backfill'
  end

  after { Spree.maintenance_tasks.delete('TestMaintenance::Backfill') }

  describe 'GET #index' do
    it 'lists the registered tasks' do
      get :index

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |task| task['name'] }
      expect(names).to include('TestMaintenance::Backfill')
    end

    it 'describes each task well enough to render its form' do
      get :index

      task = json_response['data'].find { |entry| entry['name'] == 'TestMaintenance::Backfill' }
      expect(task['description']).to eq('Backfill the thing')
      expect(task['supports_dry_run']).to be(true)

      label = task['parameters'].find { |parameter| parameter['name'] == 'label' }
      expect(label['required']).to be(true)

      mode = task['parameters'].find { |parameter| parameter['name'] == 'mode' }
      expect(mode['options']).to eq(%w[fast thorough])
    end

    # Upgrade steps belong to the upgrade panel, which owns their order and
    # notes; the flag keeps them out of the loose task list even on an
    # installation with no upgrade to run.
    it 'marks the tasks that are upgrade manifest steps' do
      get :index

      upgrade = json_response['data'].find { |entry| entry['name'].include?('MaintenanceTasks::Upgrade::') }
      own = json_response['data'].find { |entry| entry['name'] == 'TestMaintenance::Backfill' }

      expect(upgrade['upgrade_step']).to be(true)
      expect(own['upgrade_step']).to be(false)
    end

    it 'flags masked parameters so the form never echoes them back' do
      get :index

      task = json_response['data'].find { |entry| entry['name'] == 'TestMaintenance::Backfill' }
      token = task['parameters'].find { |parameter| parameter['name'] == 'token' }

      expect(token['masked']).to be(true)
    end

    it 'reports the last run and whether one is in flight' do
      run = create(:maintenance_task_run, task_name: 'TestMaintenance::Backfill', status: 'running')

      get :index

      task = json_response['data'].find { |entry| entry['name'] == 'TestMaintenance::Backfill' }
      expect(task['last_run']['id']).to eq(run.prefixed_id)
      expect(task['active_run']['id']).to eq(run.prefixed_id)
    end

    it 'reports no active run once the last one finished' do
      create(:maintenance_task_run, task_name: 'TestMaintenance::Backfill', status: 'succeeded')

      get :index

      task = json_response['data'].find { |entry| entry['name'] == 'TestMaintenance::Backfill' }
      expect(task['active_run']).to be_nil
      expect(task['last_run']).to be_present
    end
  end

  describe 'GET #show' do
    it 'finds a task by its class name' do
      get :show, params: { id: 'TestMaintenance::Backfill' }

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['name']).to eq('TestMaintenance::Backfill')
    end

    it '404s for a class that is not registered' do
      get :show, params: { id: 'Nope::Task' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
