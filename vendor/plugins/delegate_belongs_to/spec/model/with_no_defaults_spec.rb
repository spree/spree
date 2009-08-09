require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe DelegateBelongsTo, 'with no default delegations and one specified delegation' do

  before :all do
    @fields = [:fullname]
    UserNoDefault.delegate_belongs_to :contact, *@fields
  end

  before :each do
    @user = UserNoDefault.new      
  end

  it 'should declare the association' do
    UserNoDefault.reflect_on_association(:contact).should_not be_nil
  end

  it 'creates reader methods for fields' do
    @fields.each do |col|
      @user.should respond_to(col)
    end
  end

  it 'creates writer methods for fields' do
    @fields.each do |col|
      @user.should respond_to("#{col}=")
    end
  end

end
