require_relative 'preview_data'

# Preview Spree export emails at /rails/mailers/spree/export
class Spree::ExportPreview < ActionMailer::Preview
  def export_done
    Spree::ExportMailer.export_done(export)
  end

  private

  # Reuse the most recent export, or build an in-memory example so the preview
  # works on a database that has never run an export. The record is never saved,
  # so no `export.created` side effects (attachment upload, generate job) fire.
  def export
    Spree::Export.last || example_export
  end

  def example_export
    export = Spree::Exports::Products.new(
      id: 0,
      store: Spree::Store.default,
      user: Spree::PreviewData.admin_user,
      format: :csv
    )
    export.attachment.attach(
      io: StringIO.new("id,name,price\n1,Example Product,19.99\n"),
      filename: 'products-export.csv',
      content_type: 'text/csv'
    )
    export
  end
end
