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
      attribute :product_id, :string
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
    let(:valid_params) { { task_name: 'runs', arguments: { label: 'nightly' } } }

    it 'starts a run and enqueues the runner' do
      expect { post :create, params: valid_params }.to have_enqueued_job(Spree::MaintenanceTasks::RunJob)

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('enqueued')
      expect(json_response['task_name']).to eq('runs')
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
      post :create, params: { task_name: 'runs', arguments: {} }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'passes an argument holding a prefixed id through as given' do
      product = create(:product, store: store)

      post :create, params: { task_name: 'runs', arguments: { label: 'x', product_id: product.prefixed_id } }

      expect(Spree::MaintenanceTaskRun.last.arguments['product_id']).to eq(product.prefixed_id)
    end

    it 'rejects an argument the task does not declare' do
      post :create, params: { task_name: 'runs', arguments: { label: 'x', nope: '1' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a task that is not registered' do
      post :create, params: { task_name: 'nope' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    # A class name never crosses the API, in either direction.
    it 'rejects a task named by its class name' do
      post :create, params: valid_params.merge(task_name: 'TestMaintenance::Runs')

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::MaintenanceTaskRun.count).to eq(0)
    end

    it 'refuses a second run while one is in flight' do
      create(:maintenance_task_run, task_name: 'TestMaintenance::Runs', status: 'running')

      post :create, params: valid_params

      expect(response).to have_http_status(:unprocessable_content)
    end

    # A run is reproducible only if it kept what it was given, but the value
    # must never travel back out.
    it 'masks sensitive arguments in the response' do
      post :create, params: { task_name: 'runs',
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

      get :index, params: { q: { task_name_eq: 'runs' } }

      expect(json_response['data'].map { |entry| entry['task_name'] }.uniq).to eq(['runs'])
    end

    it 'finds runs by part of the task name' do
      get :index, params: { q: { task_name_cont: 'run' } }

      expect(json_response['data'].map { |entry| entry['id'] }).to include(run.prefixed_id)
    end

    it 'embeds who started a run when asked to' do
      run.update!(admin_user: admin_user)

      get :index, params: { expand: 'admin_user' }

      entry = json_response['data'].find { |candidate| candidate['id'] == run.prefixed_id }
      expect(entry['admin_user_id']).to eq(admin_user.prefixed_id)
      expect(entry['admin_user']['email']).to eq(admin_user.email)
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
      post :create, params: { task_name: 'from_csv', csv_file: signed_id }

      expect(response).to have_http_status(:created)
      expect(Spree::MaintenanceTaskRun.last.csv_file).to be_attached
    end

    it 'refuses a run with no file' do
      post :create, params: { task_name: 'from_csv' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses an invalid signed id rather than failing the request' do
      post :create, params: { task_name: 'from_csv', csv_file: 'not-a-signed-id' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'runs are never deleted through the API' do
    it 'has no destroy route' do
      expect { delete :destroy, params: { id: 1 } }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
