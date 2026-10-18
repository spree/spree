require 'spec_helper'
require 'rake'

describe 'spree:upgrade:tax_exemption_reasons' do
  subject { Rake::Task['spree:upgrade:tax_exemption_reasons'] }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'tax_exemption_reasons.rake')
  end

  before { subject.reenable }

  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  # A code saved before codes were upper-cased. Written as SQL because the
  # normalizer upper-cases hash values even in update_all.
  def legacy_code(reason, code)
    Spree::TaxExemptionReason.where(id: reason.id).update_all(['code = ?', code])
  end

  # What a certificate recorded before reasons existed looks like.
  def legacy_certificate(reason_code)
    create(:tax_exemption_certificate, company: company).tap do |certificate|
      certificate.update_columns(tax_exemption_reason_id: nil, reason_code: reason_code)
    end
  end

  it 'gives the store the default reasons' do
    subject.invoke

    expect(store.tax_exemption_reasons.pluck(:code)).to include(*Spree::Seeds::TaxExemptionReasons::REASONS.keys)
  end

  it 'saves a lower-case code in capitals' do
    reason = create(:tax_exemption_reason, store: store, name: 'Diplomatic')
    legacy_code(reason, 'diplomatic')

    subject.invoke

    expect(reason.reload.code).to eq('DIPLOMATIC')
  end

  it 'leaves a lower-case code alone when its capitals are taken' do
    create(:tax_exemption_reason, store: store, code: 'DIPLOMATIC', name: 'Diplomatic')
    reason = create(:tax_exemption_reason, store: store, name: 'Embassy')
    legacy_code(reason, 'diplomatic')

    expect { subject.invoke }.to output(/DIPLOMATIC is taken/).to_stdout

    expect(reason.reload.code).to eq('diplomatic')
  end

  it 'links a certificate to the reason matching its old code' do
    certificate = legacy_certificate('resale')

    expect { subject.invoke }.to output(/Linked 1/).to_stdout

    expect(certificate.reload.tax_exemption_reason.code).to eq('RESALE')
  end

  it 'creates a reason for a code no reason holds' do
    certificate = legacy_certificate('diplomatic')

    expect { subject.invoke }.to output.to_stdout

    expect(certificate.reload.tax_exemption_reason).to have_attributes(code: 'DIPLOMATIC', name: 'Diplomatic')
  end
end
