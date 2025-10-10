require 'spec_helper'

RSpec.describe Spree::ExportMailer, type: :mailer do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:export) { create(:product_export, store: store, user: user) }
  let(:spree) { Spree::Core::Engine.routes.url_helpers }

  before do
    export.generate
    export.reload
    allow(spree).to receive(:admin_export_url).and_return("http://test.com/admin/exports/#{export.id}")
  end

  describe '#export_done' do
    subject(:mail) { described_class.export_done(export) }

    it 'renders the subject' do
      expect(mail.subject).to eq(
        Spree.t('export_mailer.export_done.subject', export_number: export.number)
      )
    end

    it 'sends to the correct recipient' do
      expect(mail.to).to eq([user.email])
    end

    it 'includes export attachment filename' do
      expect(mail.body.encoded).to include(export.attachment.filename.to_s)
    end

    it 'includes download link in the body' do
      expect(mail.body.encoded).to include("/admin/exports/#{export.id}")
    end
  end
end
