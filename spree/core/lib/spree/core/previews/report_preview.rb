# Preview Spree report emails at /rails/mailers/spree/report
class Spree::ReportPreview < ActionMailer::Preview
  def report_done
    Spree::ReportMailer.report_done(report)
  end

  private

  # Reuse the most recent report, or build a renderable one on the fly so the
  # preview works on a database that has never run a report.
  def report
    Spree::Report.last || create_example_report
  end

  def create_example_report
    store = Spree::Store.default
    report = Spree::Reports::SalesTotal.create!(
      store: store,
      user: Spree.admin_user_class.first,
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
