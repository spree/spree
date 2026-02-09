shared_examples_for 'access granted' do
  it 'should allow show' do
    expect(ability).to be_able_to(:show, resource, token) if token
    expect(ability).to be_able_to(:show, resource) unless token
  end

  it 'should allow create' do
    expect(ability).to be_able_to(:create, resource, token) if token
    expect(ability).to be_able_to(:create, resource) unless token
  end

  it 'should allow update' do
    expect(ability).to be_able_to(:update, resource, token) if token
    expect(ability).to be_able_to(:update, resource) unless token
  end
end

shared_examples_for 'access denied' do
  it 'should not allow read' do
    expect(ability).to_not be_able_to(:read, resource)
  end

  it 'should not allow create' do
    expect(ability).to_not be_able_to(:create, resource)
  end

  it 'should not allow update' do
    expect(ability).to_not be_able_to(:update, resource)
  end
end

shared_examples_for 'admin granted' do
  it 'should allow admin' do
    expect(ability).to be_able_to(:admin, resource, token) if token
    expect(ability).to be_able_to(:admin, resource) unless token
  end
end

shared_examples_for 'admin denied' do
  it 'should not allow admin' do
    expect(ability).to_not be_able_to(:admin, resource)
  end
end

shared_examples_for 'index allowed' do
  it 'should allow index' do
    expect(ability).to be_able_to(:index, resource)
  end
end

shared_examples_for 'no index allowed' do
  it 'should not allow index' do
    expect(ability).to_not be_able_to(:index, resource)
  end
end

shared_examples_for 'create only' do
  it 'should allow create' do
    expect(ability).to be_able_to(:create, resource)
  end

  it 'should not allow read' do
    expect(ability).to_not be_able_to(:read, resource)
  end

  it 'should not allow update' do
    expect(ability).to_not be_able_to(:update, resource)
  end
end

shared_examples_for 'read only' do
  it 'should not allow create' do
    expect(ability).to_not be_able_to(:create, resource)
  end

  it 'should not allow update' do
    expect(ability).to_not be_able_to(:update, resource)
  end

  it 'should allow index' do
    expect(ability).to be_able_to(:index, resource)
  end
end

shared_examples_for 'update only' do
  it 'should not allow create' do
    expect(ability).to_not be_able_to(:create, resource)
  end

  it 'should not allow read' do
    expect(ability).to_not be_able_to(:read, resource)
  end

  it 'should allow update' do
    expect(ability).to be_able_to(:update, resource)
  end
end
