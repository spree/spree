require 'spec_helper'

# How the agent's report tool reads a date grain and a time range. The tool's
# permission checks and row labels are covered with the other agent tools in
# spree_api.
RSpec.describe Spree::AgentTools::QueryReport do
  let(:store) { @default_store }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: create(:admin_user), granted_scopes: %w[read_reports read_orders])
  end

  def report(**arguments)
    described_class.new(context).call(**arguments)
  end

  def picked_grain(**arguments)
    report(metrics: ['orders'], dimensions: ['completed_at'], **arguments).dig(:meta, :dimensions, 0, :grain)
  end

  # A saved report holds its date dimension as {name, grain}, and the schema
  # handed to a client must let that through.
  it 'offers a date dimension with a grain in its schema' do
    items = described_class.input_schema.dig('properties', 'dimensions', 'items')

    expect(items).to eq('anyOf' => [{ 'type' => 'string' }, { 'type' => 'object' }])
  end

  it 'groups a date dimension by the grain it is given' do
    [Time.zone.parse('2026-01-15 12:00'), Time.zone.parse('2026-03-10 12:00')].each do |completed_at|
      create(:completed_order_with_totals, store: store).update_columns(completed_at: completed_at)
    end

    result = report(metrics: ['orders'], dimensions: [{ 'name' => 'completed_at', 'grain' => 'month' }],
                    time_range: { 'since' => '2026-01-01', 'until' => '2026-03-31' })

    expect(result.dig(:meta, :dimensions)).to eq([{ name: :completed_at, grain: :month }])
    orders_by_month = result[:rows].to_h { |row| [row.dig(:dimensions, :completed_at), row.dig(:metrics, :orders, :value)] }
    expect(orders_by_month).to eq('2026-01-01' => 1, '2026-02-01' => 0, '2026-03-01' => 1)
  end

  it 'refuses a grain that is not a name' do
    [5, []].each do |grain|
      result = report(metrics: ['orders'], dimensions: [{ 'name' => 'completed_at', 'grain' => grain }])

      expect(result[:error]).to eq('grain for completed_at must be a string')
    end
  end

  # Hour grain is the reporting default, and over a year it is refused with
  # advice the model cannot follow without a grain of its own.
  it 'picks a grain that fits the range when given none' do
    expect(picked_grain(time_range: { 'preset' => 'today' })).to eq(:hour)
    expect(picked_grain(time_range: { 'preset' => 'last_30_days' })).to eq(:day)
    expect(picked_grain(time_range: { 'preset' => 'last_90_days' })).to eq(:week)
    expect(picked_grain(time_range: { 'preset' => 'last_12_months' })).to eq(:month)
  end

  # Counted as the report labels them: from the start of the first hour, and
  # in weeks that start on Monday.
  it 'counts buckets the way the report labels them' do
    expect(picked_grain(time_range: { 'since' => '2026-01-01T00:30:00Z', 'until' => '2026-01-02T06:29:00Z' })).to eq(:hour)
    expect(picked_grain(time_range: { 'since' => '2026-01-01T00:30:00Z', 'until' => '2026-01-02T07:29:00Z' })).to eq(:day)
    expect(picked_grain(time_range: { 'since' => '2026-01-04', 'until' => '2026-08-08' })).to eq(:month)
  end

  # A store whose clocks change inside the range still has 31 calendar days in
  # the last 30, so it stays daily.
  it 'counts days on the store calendar across a clock change' do
    allow(store).to receive(:preferred_timezone).and_return('America/New_York')

    expect(picked_grain(time_range: { 'since' => '2026-10-15', 'until' => '2026-11-14' })).to eq(:day)
  end

  # Options the agent set on the dimension reach the query, which accepts or
  # refuses them, rather than being dropped with the missing grain.
  it 'keeps the options given with a date dimension' do
    result = report(metrics: ['orders'], dimensions: [{ 'name' => 'completed_at', 'include_empty' => true }])

    expect(result[:error]).to include('does not support include_empty')
  end

  it 'reads a range written as from and to' do
    range = report(metrics: ['orders'], time_range: { 'from' => '2026-09-01', 'to' => '2026-11-30' }).dig(:meta, :time_range)

    expect(range.first.to_date).to eq(Date.new(2026, 9, 1))
    expect(range.last.to_date).to eq(Date.new(2026, 11, 30))
  end

  # Returning the first 50 of 60 months would read as a complete series next
  # to totals that cover all 60.
  it 'refuses a date series longer than the row limit' do
    five_years = { 'since' => '2021-01-01', 'until' => '2025-12-31' }

    result = report(metrics: ['orders'], dimensions: ['completed_at'], time_range: five_years)
    expect(result[:error]).to eq('This report has 60 rows, more than the limit of 50. ' \
                                 'Shorten the range, use a coarser grain, or raise limit (up to 500).')

    expect(report(metrics: ['orders'], dimensions: ['completed_at'], limit: 60, time_range: five_years)[:row_count]).to eq(60)
  end

  # With a second dimension only the groups that sold become rows, so the
  # calendar says nothing about the row count.
  it 'counts the rows a report returns, not the periods in its range' do
    create(:completed_order_with_totals, store: store).update_columns(completed_at: Time.zone.parse('2023-06-15 12:00'))

    result = report(metrics: ['orders'], dimensions: [{ 'name' => 'completed_at', 'grain' => 'month' }, 'channel'],
                    time_range: { 'since' => '2021-01-01', 'until' => '2025-12-31' })

    expect(result[:error]).to be_nil
    expect(result[:row_count]).to eq(1)
  end

  # A sorted series is a ranking ("the five best days"), cut on purpose.
  it 'cuts a sorted series at the limit' do
    result = report(metrics: ['orders'], dimensions: ['completed_at'], sort: '-orders', limit: 5,
                    time_range: { 'preset' => 'last_30_days' })

    expect(result[:error]).to be_nil
    expect(result[:row_count]).to eq(5)
  end

  it 'picks a grain that fits a smaller limit' do
    expect(picked_grain(limit: 5, time_range: { 'since' => '2026-01-01', 'until' => '2026-01-10' })).to eq(:week)
  end

  it 'refuses a preset given with dates' do
    result = report(metrics: ['orders'], time_range: { 'preset' => 'last_month', 'since' => '2026-01-01' })

    expect(result[:error]).to eq('time_range takes a preset or since and until, not both')
  end

  it 'refuses a range given both as from and as since' do
    result = report(metrics: ['orders'], time_range: { 'since' => '2026-09-01', 'from' => '2026-10-01' })

    expect(result[:error]).to eq('time_range takes from or since, not both')
  end

  it 'refuses a range it cannot read rather than reporting on another' do
    result = report(metrics: ['orders'], time_range: { 'start' => '2026-09-01' })

    expect(result[:error]).to include('time_range does not take start')
  end
end
