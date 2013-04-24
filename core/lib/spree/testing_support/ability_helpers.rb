shared_examples_for 'access granted' do
  it 'should allow read' do
    ability.should be_able_to(:read, resource, token) if token
    ability.should be_able_to(:read, resource) unless token
  end

  it 'should allow create' do
    ability.should be_able_to(:create, resource, token) if token
    ability.should be_able_to(:create, resource) unless token
  end

  it 'should allow update' do
    ability.should be_able_to(:update, resource, token) if token
    ability.should be_able_to(:update, resource) unless token
  end
end

shared_examples_for 'access denied' do
  it 'should not allow read' do
    ability.should_not be_able_to(:read, resource)
  end

  it 'should not allow create' do
    ability.should_not be_able_to(:create, resource)
  end

  it 'should not allow update' do
    ability.should_not be_able_to(:update, resource)
  end
end

shared_examples_for 'admin granted' do
  it 'should allow admin' do
    ability.should be_able_to(:admin, resource, token) if token
    ability.should be_able_to(:admin, resource) unless token
  end
end

shared_examples_for 'admin denied' do
  it 'should not allow admin' do
    ability.should_not be_able_to(:admin, resource)
  end
end

shared_examples_for 'index allowed' do
  it 'should allow index' do
    ability.should be_able_to(:index, resource)
  end
end

shared_examples_for 'no index allowed' do
  it 'should not allow index' do
    ability.should_not be_able_to(:index, resource)
  end
end

shared_examples_for 'create only' do
  it 'should allow create' do
    ability.should be_able_to(:create, resource)
  end

  it 'should not allow read' do
    ability.should_not be_able_to(:read, resource)
  end

  it 'should not allow update' do
    ability.should_not be_able_to(:update, resource)
  end

  it 'should not allow index' do
    ability.should_not be_able_to(:index, resource)
  end
end

shared_examples_for 'read only' do
  it 'should not allow create' do
    ability.should_not be_able_to(:create, resource)
  end

  it 'should not allow update' do
    ability.should_not be_able_to(:update, resource)
  end

  it 'should allow index' do
    ability.should be_able_to(:index, resource)
  end
end

shared_examples_for 'update only' do
  it 'should not allow create' do
    ability.should_not be_able_to(:create, resource)
  end

  it 'should not allow read' do
    ability.should_not be_able_to(:read, resource)
  end

  it 'should allow update' do
    ability.should be_able_to(:update, resource)
  end

  it 'should not allow index' do
    ability.should_not be_able_to(:index, resource)
  end
end
