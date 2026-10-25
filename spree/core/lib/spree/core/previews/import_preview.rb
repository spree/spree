require_relative 'preview_data'

# Preview Spree import emails at /rails/mailers/spree/import
class Spree::ImportPreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def import_done
    Spree::ImportMailer.import_done(Spree::Import.where.not(user_id: nil).last)
  end
end
