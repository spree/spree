require File.dirname(__FILE__) + '/../spec_helper'

describe LocaleController do

  #Delete these examples and add some real ones
  it "should inherit from ApplicationController" do
    controller.should be_a_kind_of(ApplicationController)
  end

  it 'should redirect when a locale is set' do
    get 'set', { :locale => 'en-US'}
    response.should be_redirect
    flash[:notice].should eql("Locale Changed")
  end

  it 'should set a correct value for session[:locale]' do
    get 'set', { :locale => 'es'}
    session[:locale].should eql('es')
    flash[:notice].should eql('Se ha cambiado el idioma')
  end

  describe 'route generation' do
    it 'should generate correct routes' do
      # set_locale_path(:locale => 'es-ES').should == "/locale/set?locale=es-ES"
      route_for(:controller => 'locale', :action => 'set', :locale => 'en-US', :method => :get).should == "/locale/set?locale=en-US"
    end
  end

  describe 'route recognition' do
    it 'should generate params {:controller => "locale", :action => "set"} from GET /locale/set' do
      params_from(:get, '/locale/set').should == {:controller => 'locale', :action => 'set', :method => :get}
    end
  end

end
