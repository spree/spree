# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Maintenance Tasks API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/maintenance_tasks' do
    get 'List maintenance tasks' do
      tags 'Maintenance Tasks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the maintenance tasks this installation can run — data
        corrections, backfills and reindexes that ship with the store's code
        (see `docs/plans/6.0-maintenance-tasks.md`).

        A task is a deployed class rather than a record, so it is identified by
        its class name. Each entry carries the `parameters` schema a run form is
        built from, whether it `supports_dry_run`, whether its rows come from a
        `csv` upload, and how its last run went.
      DESC
      admin_scope :read, :maintenance_tasks

      admin_sdk_example 'maintenance-tasks/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'maintenance tasks found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].first).to include('name', 'parameters', 'supports_dry_run')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/maintenance_task_runs' do
    get 'List maintenance task runs' do
      tags 'Maintenance Tasks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The record of every maintenance task run: who started it, with which
        arguments, how far it got and how it ended.

        Runs are installation-wide rather than per store — a backfill walks
        every store's data — so this list is not filtered by the store the
        request is made against. The `store_id` on a run records where the
        operator was working when they started it.
      DESC
      admin_scope :read, :maintenance_tasks

      admin_sdk_example 'maintenance-task-runs/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[task_name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by task name (contains)'
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false,
                description: 'Filter by status (enqueued, running, paused, succeeded, errored, cancelled, …)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'maintenance task runs found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:maintenance_task_run) do
          create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods',
                                        status: 'succeeded', initiated_via: 'dashboard')
        end

        schema SwaggerSchemaHelpers.paginated('MaintenanceTaskRun')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |run| run['id'] }).to include(maintenance_task_run.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Start a maintenance task' do
      tags 'Maintenance Tasks'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Starts a run of a registered maintenance task and returns it. The run
        is enqueued, so poll it while `active` is true.

        `arguments` are validated by the task's own Active Model validations,
        so a bad value is rejected here rather than failing on the first
        record. `dry_run` is honored only by tasks whose `supports_dry_run` is
        true — recording a run as a preview that would in fact have written
        would misrepresent what happened.

        Only one run of a task can be in flight at a time: two would race over
        the same records and their cursors would leapfrog.
      DESC
      admin_scope :write, :maintenance_tasks

      admin_sdk_example 'maintenance-task-runs/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          task_name: { type: :string, example: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods' },
          arguments: { type: :object, example: {} },
          dry_run: { type: :boolean, example: true },
          csv_file: { type: :string, description: 'Signed id of an uploaded blob, for tasks whose rows come from a CSV' }
        },
        required: %w[task_name]
      }

      response '201', 'maintenance task started' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods', dry_run: true }
        end

        schema '$ref' => '#/components/schemas/MaintenanceTaskRun'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('enqueued')
          expect(data['dry_run']).to be(true)
        end
      end

      response '422', 'task is not registered' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { task_name: 'Nope::Task' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/maintenance_task_runs/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Maintenance task run ID'

    get 'Retrieve a maintenance task run' do
      tags 'Maintenance Tasks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        A single run, with the progress a dashboard polls while it works.

        `progress` is `0..1` when the task could count its collection and
        `null` when it could not, in which case `tick_count` alone reports what
        has been processed. `arguments` are rendered through the task's masking
        rules, so a secret passed as a parameter is stored for reproducibility
        but never echoed back.
      DESC
      admin_scope :read, :maintenance_tasks

      admin_sdk_example 'maintenance-task-runs/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'maintenance task run found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:maintenance_task_run) do
          create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods',
                                        status: 'running', tick_count: 5, tick_total: 20)
        end
        let(:id) { maintenance_task_run.prefixed_id }

        schema '$ref' => '#/components/schemas/MaintenanceTaskRun'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['progress']).to eq(0.25)
          expect(data['active']).to be(true)
        end
      end

      response '404', 'maintenance task run not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'mtr_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/maintenance_task_runs/{id}/cancel' do
    parameter name: :id, in: :path, type: :string, description: 'Maintenance task run ID'

    patch 'Cancel a maintenance task run' do
      tags 'Maintenance Tasks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Asks the runner to stop for good at its next checkpoint.

        Cancelling is not a rollback — work already committed stays committed.
        What a cancelled run keeps is its cursor, so an operator can see how
        far it got. Use `pause` instead to stop a run that should be resumed
        later, and `resume` to pick a paused or failed run back up.
      DESC
      admin_scope :write, :maintenance_tasks

      admin_sdk_example 'maintenance-task-runs/cancel'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'maintenance task run cancelling' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:maintenance_task_run) do
          create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods',
                                        status: 'running')
        end
        let(:id) { maintenance_task_run.prefixed_id }

        schema '$ref' => '#/components/schemas/MaintenanceTaskRun'

        run_test! do |response|
          # The service records the request; the runner records the outcome, so
          # a running run reports `cancelling` rather than `cancelled` here.
          expect(JSON.parse(response.body)['status']).to eq('cancelling')
        end
      end

      response '422', 'maintenance task run cannot be cancelled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:maintenance_task_run) do
          create(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods',
                                        status: 'succeeded')
        end
        let(:id) { maintenance_task_run.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
