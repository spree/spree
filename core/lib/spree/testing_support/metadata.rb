shared_examples_for 'metadata' do |factory: described_class.name.demodulize.underscore.to_sym|
  subject { FactoryBot.create(factory) }

  it { expect(subject.has_attribute?(:public_metadata)).to be_truthy }
  it { expect(subject.has_attribute?(:private_metadata)).to be_truthy }

  it { expect(subject.public_metadata).to eq({}) }
  it { expect(subject.private_metadata).to eq({}) }

  it { expect(subject.public_metadata.class).to eq(ActiveSupport::HashWithIndifferentAccess) }
  it { expect(subject.private_metadata.class).to eq(ActiveSupport::HashWithIndifferentAccess) }

  it 'reads data as symbolized keys' do
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

  it 'reads data as not symbolized keys' do
    string = subject.public_metadata[:color] = 'red'
    number = subject.public_metadata[:priority] = 1
    array = subject.public_metadata[:keywords] = ['k1', 'k2']
    hash = subject.public_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(subject.public_metadata['color']).to eq(string)
    expect(subject.public_metadata['priority']).to eq(number)
    expect(subject.public_metadata['keywords']).to eq(array)
    expect(subject.public_metadata['additional_data']).to eq(hash.stringify_keys)
  end

  it 'can query records by metadata properties', skip: ENV['DB'] == 'mysql' do
    subject.public_metadata[:color] = 'red'
    subject.public_metadata[:priority] = 1
    subject.public_metadata[:keywords] = ['k1', 'k2']
    subject.public_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(described_class.where("public_metadata->>'color' = ?", 'red').count).to eq(1)
    expect(described_class.where("public_metadata->>'priority' = ?", '1').count).to eq(1)
    expect(described_class.where("public_metadata -> 'keywords' ? :keyword", keyword: 'k1').count).to eq(1)
    expect(described_class.where("public_metadata -> 'additional_data' ->> 'size' = :size", size: 'big').count).to eq(1)
  end
end
