require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe DelegateBelongsTo, 'with the default delegations' do

  before :all do
    @fields = Contact.column_names - UserDefault.default_rejected_delegate_columns
    UserDefault.delegate_belongs_to :contact
  end

  before :each do
    @user = UserDefault.new      
  end  

  it 'should declare the association' do
    UserDefault.reflect_on_association(:contact).should_not be_nil
  end

  it 'creates reader methods for the columns' do
    @fields.each do |col|
      @user.should respond_to(col)
    end
  end

  it 'creates writer methods for the columns' do
    @fields.each do |col|
      @user.should respond_to("#{col}=")
    end
  end

end