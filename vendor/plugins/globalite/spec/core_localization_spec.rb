# This examples can only be run if the plugin is installed in a Rails app
# Requires RSpec plugin or gem

require File.dirname(__FILE__) + '/helpers/spec_helper'
include ActionView::Helpers::DateHelper
include ActionView::Helpers::NumberHelper
include ActionView::Helpers::FormOptionsHelper

describe "when Rails is loaded" do
  
  before(:each) do
    Globalite.current_locale = 'en-US'
  end
  
  it "should have loaded fr" do
    Globalite.locales.should include(:"fr-FR")
  end  
    
  it "should have loaded the rails localization file in English and French" do
    :error_message_inclusion.l.should == "is not included in the list"
    Globalite.locale = :"fr-FR"
    Globalite.locales.should include(:"fr-FR")
    Globalite.locale.should == :"fr-FR"
    Globalite.localizations.keys.should include(:error_message_inclusion)
    Globalite.localizations[:error_message_inclusion].should_not be(nil)
    :error_message_inclusion.l.should == "n'est pas inclus dans la liste."
  end
  
  it "ActiveRecord error messages should be localized in English" do
    ActiveRecord::Errors.default_error_messages[:confirmation].should include("doesn't match confirmation")
    Globalite.current_language = :fr
    ActiveRecord::Errors.default_error_messages[:confirmation].should include("ne correspond pas à la confirmation")
  end
  
  it "distance_of_time_in_words should be localized properly" do
    from = Time.mktime(2004, 3, 6, 21, 41, 18).utc
    distance_of_time_in_words(from, Time.mktime(2004, 3, 6, 21, 41, 25).utc).should == "less than a minute"
    distance_of_time_in_words(Time.mktime(2004, 3, 7, 1, 20).utc, from).should == "about 4 hours"
    Globalite.language = :fr
    distance_of_time_in_words(from, Time.mktime(2004, 3, 6, 21, 41, 25).utc).should == "moins d'une minute"
    distance_of_time_in_words(Time.mktime(2004, 3, 7, 1, 20).utc, from).should == "environ 4 heures"
  end
  
  it "currency should be localized" do
     number_to_currency(123).should == "$123.00"
     Globalite.current_language = :fr
     number_to_currency(123).should == "123,00 €"
  end
  
  it "should support different locales" do
    Globalite.current_locale = :"en-US"
    number_to_currency(123).should == "$123.00"
    Globalite.current_locale = :"en-UK"
    number_to_currency(123).should == "£123.00"
  end
  
  it "date_select should be localized" do
    select_day(Time.parse("Sat Aug 16 07:00:00 UTC 2003")).should == %Q(<select id=\"date_day\" name=\"date[day]\">\n<option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option>\n<option value=\"5\">5</option>\n<option value=\"6\">6</option>\n<option value=\"7\">7</option>\n<option value=\"8\">8</option>\n<option value=\"9\">9</option>\n<option value=\"10\">10</option>\n<option value=\"11\">11</option>\n<option value=\"12\">12</option>\n<option value=\"13\">13</option>\n<option value=\"14\">14</option>\n<option value=\"15\">15</option>\n<option selected=\"selected\" value=\"16\">16</option>\n<option value=\"17\">17</option>\n<option value=\"18\">18</option>\n<option value=\"19\">19</option>\n<option value=\"20\">20</option>\n<option value=\"21\">21</option>\n<option value=\"22\">22</option>\n<option value=\"23\">23</option>\n<option value=\"24\">24</option>\n<option value=\"25\">25</option>\n<option value=\"26\">26</option>\n<option value=\"27\">27</option>\n<option value=\"28\">28</option>\n<option value=\"29\">29</option>\n<option value=\"30\">30</option>\n<option value=\"31\">31</option>\n</select>\n)
    select_day(Time.parse("Sat Aug 16 07:00:00 UTC 2003"), :include_blank => true).should == %Q(<select id="date_day" name="date[day]">\n<option value=""></option>\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option selected="selected" value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n</select>\n)
    select_day(16, :include_blank => true).should == %Q(<select id="date_day" name="date[day]">\n<option value=""></option>\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option selected="selected" value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n</select>\n)
    Globalite.current_language = :fr
    select_day(Time.parse("Sat Aug 16 07:00:00 UTC 2003")).should == %Q(<select id=\"date_day\" name=\"date[day]\">\n<option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option>\n<option value=\"4\">4</option>\n<option value=\"5\">5</option>\n<option value=\"6\">6</option>\n<option value=\"7\">7</option>\n<option value=\"8\">8</option>\n<option value=\"9\">9</option>\n<option value=\"10\">10</option>\n<option value=\"11\">11</option>\n<option value=\"12\">12</option>\n<option value=\"13\">13</option>\n<option value=\"14\">14</option>\n<option value=\"15\">15</option>\n<option selected=\"selected\" value=\"16\">16</option>\n<option value=\"17\">17</option>\n<option value=\"18\">18</option>\n<option value=\"19\">19</option>\n<option value=\"20\">20</option>\n<option value=\"21\">21</option>\n<option value=\"22\">22</option>\n<option value=\"23\">23</option>\n<option value=\"24\">24</option>\n<option value=\"25\">25</option>\n<option value=\"26\">26</option>\n<option value=\"27\">27</option>\n<option value=\"28\">28</option>\n<option value=\"29\">29</option>\n<option value=\"30\">30</option>\n<option value=\"31\">31</option>\n</select>\n)
    
  end
  
  it "datetime_select should be localized" do
    select_datetime(nil, :prefix => "date[first]").should include('January')
    Globalite.language = :fr
    select_datetime(nil, :prefix => "date[first]").should include('Janvier')
  end
  
  describe '#select_month' do
    it "should localize the month's names and their abbreviations" do
      select_month(Time.mktime(2003, 8, 16)).should == %Q(<select id=\"date_month\" name=\"date[month]\">\n<option value=\"1\">January</option>\n<option value=\"2\">February</option>\n<option value=\"3\">March</option>\n<option value=\"4\">April</option>\n<option value=\"5\">May</option>\n<option value=\"6\">June</option>\n<option value=\"7\">July</option>\n<option value=\"8\" selected=\"selected\">August</option>\n<option value=\"9\">September</option>\n<option value=\"10\">October</option>\n<option value=\"11\">November</option>\n<option value=\"12\">December</option>\n</select>\n)
      Globalite.language = :fr
      select_month(Time.mktime(2003, 8, 16)).should == %Q(<select id=\"date_month\" name=\"date[month]\">\n<option value=\"1\">Janvier</option>\n<option value=\"2\">Février</option>\n<option value=\"3\">Mars</option>\n<option value=\"4\">Avril</option>\n<option value=\"5\">Mai</option>\n<option value=\"6\">Juin</option>\n<option value=\"7\">Juillet</option>\n<option value=\"8\" selected=\"selected\">Août</option>\n<option value=\"9\">Septembre</option>\n<option value=\"10\">Octobre</option>\n<option value=\"11\">Novembre</option>\n<option value=\"12\">Décembre</option>\n</select>\n)
    end
    
    it "should support the :use_hidden option" do
      select_month(Time.mktime(2003, 8, 16), :use_hidden => true).should == %Q(<input id=\"date_month\" name=\"date[month]\" type=\"hidden\" value=\"8\" />\n)  
    end
  end
  
  it "the country list should be localized" do
    expected_en = %Q(<option value=\"Afghanistan\">Afghanistan</option>\n<option value=\"Albania\">Albania</option>\n<option value=\"Algeria\">Algeria</option>\n<option value=\"American Samoa\">American Samoa</option>\n<option value=\"Andorra\">Andorra</option>\n<option value=\"Angola\">Angola</option>\n<option value=\"Anguilla\">Anguilla</option>\n<option value=\"Antarctica\">Antarctica</option>\n<option value=\"Antigua And Barbuda\">Antigua And Barbuda</option>\n<option value=\"Argentina\">Argentina</option>\n<option value=\"Armenia\">Armenia</option>\n<option value=\"Aruba\">Aruba</option>\n<option value=\"Australia\">Australia</option>\n<option value=\"Austria\">Austria</option>\n<option value=\"Azerbaijan\")
    country_options_for_select.should include(expected_en)
    Globalite.current_language = :fr
    expected_fr = %Q(<option value=\"Afghanistan\">Afghanistan</option>\n<option value=\"Albanie\">Albanie</option>\n<option value=\"Algérie\">Algérie</option>\n)
    country_options_for_select.should include(expected_fr)
  end
  
  it 'time should be localized' do
    t = Time.parse('2006-12-25 13:55 UTC')
    t.to_formatted_s(:long).should == 'December 25, 2006 13:55'
    Globalite.language = :fr
    t.l(:long).should == '25 Décembre, 2006 13:55'
    t.l(:short).should == '25 Déc, 13:55'
    # custom format
    t.l('%a, %A, %d %b %B %Y %H:%M:%S %p').should == "Lun, Lundi, 25 Déc Décembre 2006 13:55:00 pm"
  end
  
  it 'date should be localized' do
    d = Date.new(2007,05,13)
    d.l.should == '2007-05-13'
    Globalite.current_language = :fr
    d.l(:short).should == '13 Mai'
  end
  
  it 'an array to sentence should be localized' do
    us = ['Heidi', 'Matt']
    us.to_sentence.should == 'Heidi and Matt'
    Globalite.current_language = :fr
    us.to_sentence.should == 'Heidi et Matt'
  end
  
end