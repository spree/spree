require_relative 'preview_data'

# Preview Spree report emails at /rails/mailers/spree/report
class Spree::ReportPreview < ActionMailer::Preview
  def report_done
    Spree::ReportMailer.report_done(report)
  end

  private

  # Reuse the most recent report, or build an in-memory example so the preview
  # works on a database that has never run a report. The record is never saved,
  # so no `report.created` side effects (attachment upload, generate job) fire.
  def report
    Spree::Report.last || example_report
  end

  def example_report
    store = Spree::Store.default
    report = Spree::Reports::SalesTotal.new(
      id: 0,
      store: store,
      user: Spree::PreviewData.admin_user,
      date_from: 30.days.ago.to_date,
      date_to: Date.current,
      currency: store.default_currency
    )
    report.attachment.attach(
      io: StringIO.new("date,total\n2026-01-01,1234.56\n"),
      filename: 'sales-total.csv',
      content_type: 'text/csv'
    )
    report
  end
end
