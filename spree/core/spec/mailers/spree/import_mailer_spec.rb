require 'spec_helper'

RSpec.describe Spree::ImportMailer, type: :mailer do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:import) { create(:product_import, owner: store, user: user) }
  let(:spree) { Spree::Core::Engine.routes.url_helpers }

  before do
    import.update_columns(status: 'completed')
    create(:import_row, import: import, row_number: 1, status: 'completed')
  end

  describe '#import_done' do
    subject(:mail) { described_class.import_done(import) }

    it 'renders the subject' do
      expect(mail.subject).to eq(
        Spree.t('import_mailer.import_done.subject', import_number: import.number)
      )
    end

    it 'sends to the import owner' do
      expect(mail.to).to eq([user.email])
    end

    it 'includes the completed row count' do
      expect(mail.body.encoded).to include(
        Spree.t('import_mailer.import_done.message', completed_count: 1)
      )
    end

    context 'with failed rows' do
      before do
        create(:import_row, import: import, row_number: 2, status: 'failed', validation_errors: 'boom')
      end

      it 'calls out the failed row count' do
        expect(mail.body.encoded).to include(
          Spree.t('import_mailer.import_done.failed_message', failed_count: 1)
        )
      end
    end

    context 'when the dashboard provided a results_url' do
      before do
        import.update!(results_url: 'https://admin.example.com/store_abc/settings/imports')
      end

      it 'links to the wizard with the import param appended' do
        expect(mail.body.encoded).to include(
          "https://admin.example.com/store_abc/settings/imports?import=#{import.prefixed_id}"
        )
      end
    end

    context 'without a results_url' do
      it 'falls back to the legacy admin route when mounted' do
        allow(spree).to receive(:admin_import_url).and_return("http://test.com/admin/imports/#{import.id}")

        expect(mail.body.encoded).to include("/admin/imports/#{import.id}")
      end

      it 'renders no results button when no route is available' do
        expect(mail.body.encoded).not_to include(
          Spree.t('import_mailer.import_done.view_results')
        )
      end
    end
  end
end
