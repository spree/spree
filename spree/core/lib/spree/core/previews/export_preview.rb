require_relative 'preview_data'

# Preview Spree export emails at /rails/mailers/spree/export
class Spree::ExportPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def export_done
    Spree::ExportMailer.export_done(export)
  end

  private

  # Reuse the most recent export, or build an in-memory example so the preview
  # works on a database that has never run an export. When the preview toolbar
  # requests a locale, always use the example so its store carries that locale.
  # The example is never saved, so no `export.created` side effects fire.
  def export
    return example_export if locale.present?

    Spree::Export.last || example_export
  end

  def example_export
    export = Spree::Exports::Products.new(
      id: 0,
      store: Spree::PreviewData.store(locale),
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
