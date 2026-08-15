require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MaintenanceTaskRunsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:task_class) do
    Class.new(Spree::MaintenanceTask) do
      def self.name = 'TestMaintenance::Runs'
      supports_dry_run
      attribute :label, :string
      attribute :token, :string
      validates :label, presence: true
      mask_attribute :token
      def collection = Spree::Product.order(:id)
      def process(product) = nil
    end
  end

  before do
    stub_const('TestMaintenance::Runs', task_class)
    Spree.maintenance_tasks << 'TestMaintenance::Runs'
  end

  after { Spree.maintenance_tasks.delete('TestMaintenance::Runs') }

  describe 'POST #create' do
    let(:valid_params) { { task_name: 'TestMaintenance::Runs', arguments: { label: 'nightly' } } }

    it 'starts a run and enqueues the runner' do
      expect { post :create, params: valid_params }.to have_enqueued_job(Spree::MaintenanceTasks::RunJob)

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('enqueued')
      expect(json_response['task_name']).to eq('TestMaintenance::Runs')
    end

    it 'records who fired it and the store they were in' do
      post :create, params: valid_params

      run = Spree::MaintenanceTaskRun.last
      expect(run.admin_user).to eq(admin_user)
      expect(run.store).to eq(store)
      expect(run.initiated_via).to eq('dashboard')
    end

    it 'carries the dry-run flag through' do
      post :create, params: valid_params.merge(dry_run: true)

      expect(json_response['dry_run']).to be(true)
    end

    it 'rejects arguments the task refuses' do
      post :create, params: { task_name: 'TestMaintenance::Runs', arguments: {} }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a task that is not registered' do
      post :create, params: { task_name: 'Nope::Task' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a second run while one is in flight' do
      create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'running')

      post :create, params: valid_params

      expect(response).to have_http_status(:unprocessable_content)
    end

    # A run is reproducible only if it kept what it was given, but the value
    # must never travel back out.
    it 'masks sensitive arguments in the response' do
      post :create, params: { task_name: 'TestMaintenance::Runs',
                              arguments: { label: 'nightly', token: 'secret' } }

      expect(json_response['arguments']['token']).to eq(Spree::MaintenanceTask::MASKED_VALUE)
      expect(Spree::MaintenanceTaskRun.last.arguments['token']).to eq('secret')
    end
  end

  describe 'GET #index' do
    let!(:run) { create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'succeeded') }

    it 'lists runs' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |entry| entry['id'] }).to include(run.prefixed_id)
    end

    it 'filters by task name' do
      create(:maintenance_task_run, task_name: 'Other::Task', status: 'succeeded')

      get :index, params: { q: { task_name_eq: 'TestMaintenance::Runs' } }

      expect(json_response['data'].map { |entry| entry['task_name'] }.uniq).to eq(['TestMaintenance::Runs'])
    end

    # A backfill walks every store's data, so a run fired from one store is
    # still the history of work that touched the others.
    it 'is not scoped to the store the operator is in' do
      run.update!(store: create(:store))

      get :index

      expect(json_response['data'].map { |entry| entry['id'] }).to include(run.prefixed_id)
    end
  end

  describe 'GET #show' do
    let(:run) do
      create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'running',
                                    tick_count: 5, tick_total: 20)
    end

    it 'reports progress the dashboard can draw a bar from' do
      get :show, params: { id: run.prefixed_id }

      expect(json_response['progress']).to eq(0.25)
      expect(json_response['tick_count']).to eq(5)
      expect(json_response['active']).to be(true)
    end
  end

  describe 'PATCH #pause' do
    let(:run) { create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'running') }

    it 'asks the runner to stop' do
      patch :pause, params: { id: run.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(run.reload).to be_pausing
    end

    it 'refuses to pause a finished run' do
      run.update!(status: 'succeeded')

      patch :pause, params: { id: run.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #cancel' do
    let(:run) { create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'running') }

    it 'asks the runner to stop for good' do
      patch :cancel, params: { id: run.prefixed_id }

      expect(run.reload).to be_cancelling
    end
  end

  describe 'PATCH #resume' do
    let(:run) do
      create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'paused', cursor: '42')
    end

    it 'enqueues the run again from its cursor' do
      expect { patch :resume, params: { id: run.prefixed_id } }.
        to have_enqueued_job(Spree::MaintenanceTasks::RunJob)

      expect(run.reload).to be_enqueued
      expect(run.cursor).to eq('42')
    end

    it 'refuses to resume a cancelled run' do
      run.update!(status: 'cancelled')

      patch :resume, params: { id: run.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'a task whose rows come from a CSV' do
    let(:csv_task) do
      Class.new(Spree::MaintenanceTask) do
        def self.name = 'TestMaintenance::FromCsv'
        csv_collection
        def process(row) = nil
      end
    end

    before do
      stub_const('TestMaintenance::FromCsv', csv_task)
      Spree.maintenance_tasks << 'TestMaintenance::FromCsv'
    end

    after { Spree.maintenance_tasks.delete('TestMaintenance::FromCsv') }

    let(:signed_id) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("sku,price\nA,1.00\n"), filename: 'p.csv', content_type: 'text/csv'
      ).signed_id
    end

    it 'is advertised as needing a file' do
      get :index

      # Discovery lives on the tasks controller, but the flag is what the run
      # dialog reads to decide whether to ask for one.
      expect(Spree::MaintenanceTask.find_registered('TestMaintenance::FromCsv').collection_kind).to eq(:csv)
    end

    it 'keeps the uploaded file on the run' do
      post :create, params: { task_name: 'TestMaintenance::FromCsv', csv_file: signed_id }

      expect(response).to have_http_status(:created)
      expect(Spree::MaintenanceTaskRun.last.csv_file).to be_attached
    end

    it 'refuses a run with no file' do
      post :create, params: { task_name: 'TestMaintenance::FromCsv' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses an invalid signed id rather than failing the request' do
      post :create, params: { task_name: 'TestMaintenance::FromCsv', csv_file: 'not-a-signed-id' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'runs are never deleted through the API' do
    it 'has no destroy route' do
      expect { delete :destroy, params: { id: 1 } }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
