require 'spec_helper'

# The retry and reporting policy, exercised through DeleteProfileJob, the
# simplest job that calls Klaviyo.
RSpec.describe SpreeKlaviyo::BaseJob do
  let(:integration) { create(:klaviyo_integration, :active, store: @default_store) }
  let(:email) { 'ada@example.com' }
  let(:job) { SpreeKlaviyo::DeleteProfileJob.new(integration, email) }
  let(:reports) { [] }

  def api_error(code, headers: {}, body: nil)
    KlaviyoAPI::ApiError.new(code: code, response_headers: headers, response_body: body)
  end

  before do
    allow(Rails.error).to receive(:report) { |error, **options| reports << [error, options] }
  end

  def fail_with(error)
    allow(integration).to receive(:request_profile_deletion).and_raise(error)
  end

  it 'runs on the gem queue' do
    previous = SpreeKlaviyo.queue
    SpreeKlaviyo.queue = :klaviyo

    expect(job.queue_name).to eq('klaviyo')
  ensure
    SpreeKlaviyo.queue = previous
  end

  describe 'a 429' do
    it "is rescheduled after Klaviyo's Retry-After" do
      fail_with(api_error(429, headers: { 'Retry-After' => '30' }))

      freeze_time do
        job.perform_now

        enqueued = enqueued_jobs.last
        expect(enqueued['job_class']).to eq('SpreeKlaviyo::DeleteProfileJob')
        expect(Time.iso8601(enqueued['scheduled_at'])).to be_between(30.seconds.from_now, 33.seconds.from_now)
      end
      expect(reports).to be_empty
    end

    it 'keeps rescheduling with no attempt limit' do
      fail_with(api_error(429, headers: { 'Retry-After' => '1' }))
      job.executions = 50

      expect { job.perform_now }.to have_enqueued_job(SpreeKlaviyo::DeleteProfileJob)
      expect(reports).to be_empty
    end
  end

  # Spree::Integrations::Klaviyo raises these for a 5xx, a timeout or a
  # failed connection.
  describe 'a transient failure' do
    def transient(code = 503)
      SpreeKlaviyo::TransientError.new(code: code, response_headers: {}, response_body: nil)
    end

    # Runs the job and every retry it schedules.
    def run_with_failures(*errors)
      calls = 0
      allow_any_instance_of(Spree::Integrations::Klaviyo).to receive(:request_profile_deletion) do
        error = errors[calls] || errors.last
        calls += 1
        raise error
      end

      perform_enqueued_jobs { SpreeKlaviyo::DeleteProfileJob.perform_later(integration, email) }
      calls
    end

    [[503, 'a 5xx'], [nil, 'a timeout'], [0, 'a failed connection']].each do |code, label|
      it "retries #{label}" do
        fail_with(transient(code))

        expect { job.perform_now }.to have_enqueued_job(SpreeKlaviyo::DeleteProfileJob)
        expect(reports).to be_empty
      end
    end

    it 'is reported after the fifth attempt' do
      expect(run_with_failures(transient)).to eq(5)
      expect(reports.size).to eq(1)
    end

    it 'keeps its five attempts after rate-limit reschedules' do
      rate_limited = api_error(429, headers: { 'Retry-After' => '1' })

      expect(run_with_failures(rate_limited, rate_limited, rate_limited, transient)).to eq(3 + 5)
      expect(reports.size).to eq(1)
    end
  end

  describe 'any other 4xx' do
    # The identifier conflict on import. Stubbed as 409 until the cassettes
    # confirm the status (Phase 8).
    [403, 409].each do |code|
      it "reports a #{code} once and does not retry" do
        fail_with(api_error(code,
                            body: { errors: [{ code: 'forbidden', title: 'You do not have permission',
                                               detail: 'Missing scope for ada@example.com' }] }.to_json))

        expect { job.perform_now }.not_to have_enqueued_job
        expect(reports.size).to eq(1)
      end
    end
  end

  describe 'a report' do
    before do
      errors = [{ code: 'duplicate_profile', title: 'Conflict', detail: 'ada@example.com already exists' }]
      fail_with(api_error(409, headers: { 'X-Request' => 'ada@example.com' }, body: { errors: errors }.to_json))
      job.perform_now
    end

    it "carries the status and Klaviyo's codes and titles" do
      error, options = reports.first

      expect(error).to be_a(SpreeKlaviyo::BaseJob::RequestFailed)
      expect(options[:context]).to include(status: 409, errors: [{ 'code' => 'duplicate_profile', 'title' => 'Conflict' }])
    end

    it 'holds no email' do
      error, options = reports.first

      expect(error.message).not_to include('ada@example.com')
      expect(options.to_s).not_to include('ada@example.com')
    end
  end
end
