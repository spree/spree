require 'spec_helper'

RSpec.describe Spree::ReportMailer, type: :mailer do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:report) { create(:report, store: store, user: user) }
  let(:spree) { Spree::Core::Engine.routes.url_helpers }

  describe '#report_done' do
    subject(:mail) { described_class.report_done(report) }

    before do
      allow(spree).to receive(:admin_report_url).and_return("http://test.com/admin/reports/#{report.id}")
    end

    it 'renders the subject' do
      expect(mail.subject).to eq(
        Spree.t('report_mailer.report_done.subject', report_name: report.human_name)
      )
    end

    it 'sends to the correct recipient' do
      expect(mail.to).to eq([user.email])
    end

    it 'sends from the store mail from address' do
      expect(mail.from).to eq([store.mail_from_address])
    end

    it 'sets reply-to as the store mail from address' do
      expect(mail.reply_to).to eq([store.mail_from_address])
    end

    it 'includes download link in the body' do
      expect(mail.body.encoded).to include("/admin/reports/#{report.id}")
    end
  end
end
