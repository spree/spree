shared_examples_for 'metadata' do |factory: described_class.name.demodulize.underscore.to_sym|
  subject { FactoryBot.create(factory) }

  it { expect(subject.has_attribute?(:private_metadata)).to be_truthy }

  it { expect(subject.private_metadata).to eq({}) }

  it { expect(subject.private_metadata.class).to eq(ActiveSupport::HashWithIndifferentAccess) }

  it 'reads private_metadata as symbolized keys' do
    string = subject.private_metadata[:color] = 'red'
    number = subject.private_metadata[:priority] = 1
    array = subject.private_metadata[:keywords] = ['k1', 'k2']
    hash = subject.private_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(subject.private_metadata[:color]).to eq(string)
    expect(subject.private_metadata[:priority]).to eq(number)
    expect(subject.private_metadata[:keywords]).to eq(array)
    expect(subject.private_metadata[:additional_data]).to eq(hash.stringify_keys)
  end

  it 'reads private_metadata as string keys' do
    string = subject.private_metadata[:color] = 'red'
    number = subject.private_metadata[:priority] = 1
    array = subject.private_metadata[:keywords] = ['k1', 'k2']
    hash = subject.private_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(subject.private_metadata['color']).to eq(string)
    expect(subject.private_metadata['priority']).to eq(number)
    expect(subject.private_metadata['keywords']).to eq(array)
    expect(subject.private_metadata['additional_data']).to eq(hash.stringify_keys)
  end

  it 'can query records by metadata properties', skip: (ENV['DB'].blank? || ENV['DB'] == 'mysql') do
    subject.private_metadata[:color] = 'red'
    subject.private_metadata[:priority] = 1
    subject.private_metadata[:keywords] = ['k1', 'k2']
    subject.private_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(described_class.where("private_metadata->>'color' = ?", 'red').count).to eq(1)
    expect(described_class.where("private_metadata->>'priority' = ?", '1').count).to eq(1)
    expect(described_class.where("private_metadata -> 'keywords' ? :keyword", keyword: 'k1').count).to eq(1)
    expect(described_class.where("private_metadata -> 'additional_data' ->> 'size' = :size", size: 'big').count).to eq(1)
  end

  it 'can query records by metadata properties', skip: ENV['DB'] == 'postgres' do
    subject.private_metadata[:color] = 'red'
    subject.private_metadata[:priority] = 1
    subject.private_metadata[:additional_data] = { size: 'big', material: 'wool' }

    subject.save!

    expect(described_class.where("JSON_EXTRACT(private_metadata, '$.color') = ?", 'red').count).to eq(1)
    expect(described_class.where("JSON_EXTRACT(private_metadata, '$.priority') = 1").count).to eq(1)
    expect(described_class.where("JSON_EXTRACT(private_metadata, '$.additional_data.size') = :size", size: 'big').count).to eq(1)
  end
end
