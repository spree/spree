require_relative 'preview_data'

# Preview Spree report emails at /rails/mailers/spree/report
class Spree::ReportPreview < ActionMailer::Preview
  def report_done
    Spree::ReportMailer.report_done(report)
  end

  private

  # Reuse the most recent report, or build an in-memory example so the preview
  # works on a database that has never run a report. When the preview toolbar
  # requests a locale, always use the example so its store carries that locale.
  # The example is never saved, so no `report.created` side effects fire.
  def report
    (locale.blank? && Spree::Report.last) || example_report
  end

  def example_report
    store = Spree::PreviewData.store(locale)
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

  def locale
    @params[:locale]
  end
end
