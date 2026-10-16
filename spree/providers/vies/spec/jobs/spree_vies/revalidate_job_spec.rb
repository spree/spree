require 'spec_helper'

RSpec.describe SpreeVies::RevalidateJob do
  it 'queues a check for every number due one, leaving its verdict in place' do
    stale = create(:tax_identifier)
    stale.update_columns(validation_status: 'verified', validated_at: 91.days.ago)
    fresh = create(:tax_identifier)
    fresh.update_columns(validation_status: 'verified', validated_at: 1.day.ago)

    described_class.perform_now

    expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(stale.id).exactly(:once)
    expect(Spree::TaxIdentifiers::ValidateJob).not_to have_been_enqueued.with(fresh.id)

    expect(stale.reload.validation_status).to eq('verified')
  end

  it 'spreads the checks out at the configured rate' do
    due = create_list(:tax_identifier, 3).sort_by(&:id)
    due.each { |tax_identifier| tax_identifier.update_columns(validation_status: nil) } # never asked
    allow(SpreeVies).to receive(:revalidations_per_minute).and_return(2)

    Timecop.freeze do
      described_class.perform_now

      expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[0].id).at(Time.current)
      expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[1].id).at(30.seconds.from_now)
      expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[2].id).at(1.minute.from_now)
    end
  end

  it 'keeps to the schedule when an interrupted run resumes' do
    due = create_list(:tax_identifier, 3).sort_by(&:id)
    due.each { |tax_identifier| tax_identifier.update_columns(validation_status: nil) }
    allow(SpreeVies).to receive(:revalidations_per_minute).and_return(2)
    started_at = Time.current.change(usec: 0)
    checks_queued = -> { enqueued_jobs.count { |job| job[:job] == Spree::TaxIdentifiers::ValidateJob } }

    Timecop.freeze(started_at) do
      described_class.perform_later
      queue_adapter.with(stopping: -> { checks_queued.call == 2 }) { perform_enqueued_jobs(only: described_class) }
    end
    expect(checks_queued.call).to eq(2)

    Timecop.freeze(started_at + 30.seconds) { perform_enqueued_jobs(only: described_class) }

    expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[2].id).at(started_at + 1.minute)
  end

  it 'starts the schedule again from now when a run resumes long after it was interrupted' do
    due = create_list(:tax_identifier, 3).sort_by(&:id)
    due.each { |tax_identifier| tax_identifier.update_columns(validation_status: nil) }
    allow(SpreeVies).to receive(:revalidations_per_minute).and_return(2)
    started_at = Time.current.change(usec: 0)
    checks_queued = -> { enqueued_jobs.count { |job| job[:job] == Spree::TaxIdentifiers::ValidateJob } }

    Timecop.freeze(started_at) do
      described_class.perform_later
      queue_adapter.with(stopping: -> { checks_queued.call == 2 }) { perform_enqueued_jobs(only: described_class) }
    end

    Timecop.freeze(started_at + 2.hours) { perform_enqueued_jobs(only: described_class) }

    expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[2].id).at(started_at + 2.hours)
  end

  # The test adapter keeps a job's data as Ruby objects. A real queue adapter
  # stores it as JSON, which turns symbols and times into strings.
  it 'resumes from progress that went through JSON, as a real queue adapter stores it' do
    due = create_list(:tax_identifier, 3).sort_by(&:id)
    due.each { |tax_identifier| tax_identifier.update_columns(validation_status: nil) }
    allow(SpreeVies).to receive(:revalidations_per_minute).and_return(2)
    started_at = Time.current.change(usec: 0)
    checks_queued = -> { enqueued_jobs.count { |job| job[:job] == Spree::TaxIdentifiers::ValidateJob } }

    Timecop.freeze(started_at) do
      described_class.perform_later
      queue_adapter.with(stopping: -> { checks_queued.call == 2 }) { perform_enqueued_jobs(only: described_class) }
    end
    interrupted = enqueued_jobs.find { |job| job[:job] == described_class }
    job_data = JSON.parse(JSON.generate(interrupted.reject { |key, _| key.is_a?(Symbol) }))

    Timecop.freeze(started_at + 30.seconds) { ActiveJob::Base.execute(job_data) }

    expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[0].id).exactly(:once)
    expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(due[2].id).at(started_at + 1.minute)
  end

  it 'refuses a release rate that is not a positive whole number' do
    expect { SpreeVies.revalidations_per_minute = 0 }.to raise_error(ArgumentError, /positive whole number/)
  end
end
