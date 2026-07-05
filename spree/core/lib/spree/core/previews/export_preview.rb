# Preview Spree export emails at /rails/mailers/spree/export
class Spree::ExportPreview < ActionMailer::Preview
  def export_done
    Spree::ExportMailer.export_done(export)
  end

  private

  # Reuse the most recent export, or build a renderable one on the fly so the
  # preview works on a database that has never run an export.
  def export
    Spree::Export.last || create_example_export
  end

  def create_example_export
    export = Spree::Exports::Products.create!(
      store: Spree::Store.default,
      user: Spree.admin_user_class.first,
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
