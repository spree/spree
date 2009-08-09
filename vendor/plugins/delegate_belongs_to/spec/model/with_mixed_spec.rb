require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe DelegateBelongsTo, 'with a mix of the default delegations and a specified delegation' do

  before :all do
    @fields = Contact.column_names - UserMixed.default_rejected_delegate_columns + [:fullname]
    UserMixed.delegate_belongs_to :contact, :defaults, :fullname
  end

  before :each do
    @user = UserMixed.new      
  end

  it 'should declare the association' do
    UserMixed.reflect_on_association(:contact).should_not be_nil
  end

  it 'creates reader methods for columns' do
    @fields.each do |col|
      @user.should respond_to(col)
    end
  end

  it 'creates writer methods for columns' do
    @fields.each do |col|
      @user.should respond_to("#{col}=")
    end
  end
end
