shared_examples_for 'metadata' do |factory: described_class.name.demodulize.underscore.to_sym|
  subject { FactoryBot.create(factory) }

  it { expect(subject.has_attribute?(:public_metadata)).to be_truthy }
  it { expect(subject.has_attribute?(:private_metadata)).to be_truthy }

  it { expect(subject.public_metadata.class).to eq(HashWithIndifferentAccess) }
  it { expect(subject.private_metadata.class).to eq(HashWithIndifferentAccess) }

  it do
    string = subject.public_metadata[:color] = 'red'
    number = subject.public_metadata[:priority] = 1
    array = subject.public_metadata[:keywords] = ['k1', 'k2']
    hash = subject.public_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(subject.public_metadata[:color]).to eq(string)
    expect(subject.public_metadata[:priority]).to eq(number)
    expect(subject.public_metadata[:keywords]).to eq(array)
    expect(subject.public_metadata[:additional_data]).to eq(hash.stringify_keys)
  end
end
