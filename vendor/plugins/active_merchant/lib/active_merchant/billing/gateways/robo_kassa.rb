#coding: utf-8
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RoboKassaGateway < Gateway
      
      TEST_HTML_KASSA_URL = 'http://test.robokassa.ru/MrchSumPreview.ashx'
      LIVE_HTML_KASSA_URL = 'http://www.roboxchange.com/mrh_summpreview.asp'
      TEST_PAYMENT_FORM_URL = 'http://test.robokassa.ru/Index.aspx'
      LIVE_PAYMENT_FORM_URL = 'http://merchant.roboxchange.com/Index.aspx'

      TEST_XML_URLS = {
        :list_currency =>   "http://www.roboxchange.com/xml/currlist.asp",
        :exchange_rate =>   'http://test.robokassa.ru/Xml/Rate.ashx',
        :state_operation => "http://test.robokassa.ru/Xml/OpState.ashx"
      }
      LIVE_XML_URLS = {
        :list_currency =>   "http://www.roboxchange.com/xml/currlist.asp",
        :exchange_rate =>   'http://www.roboxchange.com/xml/rate.asp',
        :state_operation => "https://www.roboxchange.com/xmlssl/opstate.asp" 
      } 
      
      STATE_OPERATION_RET_CODE ={
        "-100" => "неверно сформирован запрос (не все требуемые параметры заданы, либо запрос не разобран вовсе)",
        "-9" =>"sSignatureValue не указана, либо неверного вида (длина должна быть 32 символа)",
        "-2" => "sInvId не задан либо не является числом", 
        "0" => "нет ошибки. При этом присутствует тег <opstate>.",
        "1" => "указанный sMerchantLogin не найден",
        "9" => "неверно задана контрольная сумма", 
        "10" => "операция с данным sInvId не найдена (возможно еще не инициирована)" }

      STATE_OPERATION ={
        '5' => 'только инициирована, деньги не получены',
        '10' => 'деньги не были получены, операция отменена',
        '50' => 'деньги от пользователя получены, производится зачисление денег на счет магазина',
        '60' => 'деньги после получения были возвращены пользователю',
        '80' => 'исполнение операции приостановлено',
        '100' => 'операция завершена успешно'
      }
      
  EXCHANGE_RATE_RET_CODE = { 
        '-100' => "неверно сформирован запрос (не все требуемые параметры заданы, либо запрос не разобран вовсе)",
        '0' => "нет ошибки.",
        '1' => "sIncCurrLabel задан неверно",
        '2' => "sOutCurrLabel задан неверно",
        '3' => "sMerchantLogin не найден",
        '4' => "nOutCnt задан неверно" 
      }

      
      # The homepage URL of the gateway
      self.homepage_url = 'http://robokassa.ru/'
      
      # The name of the gateway
      self.display_name = 'RoboKassa'

      
      # Создание нового объекта RoboKassa
      # 
      def initialize(options = {})
        @options = {
          :payment_currency => "WMR", 
          :language => "RU", 
          :encoding => "utf-8",
          :value =>"Оплатить"}
        @options.merge!(options) 
        @custom_fields = { }        
        super
      end  
      
      
      # Html код кассы и кнопки оплаты для сайта 
      # методы для создания html кода кассы и кнопки оплаты      
      # обязательные параметры 
      # :invoice = номер платежа 
      # :summa = сумма платежа
      # необязательные параметры
      # :description: описание товара ("")
      # language: язык (RU)
      # encoding: кодировка (UTF-8)
      # payment_currentcy - валюта платежа (WMR)
      # value - надпись на кнопки (Оплатить)
      def method_missing(method_id, options ={ }, shp_fields ={ })
        if (method_id == :payment_button) ||
            ( method_id == :payment_kassa)
          @options.merge!(options)
          @custom_fields = shp_fields
          @options[:signature] = Digest::MD5.hexdigest([@options[:login], @options[:summa],
                                                        @options[:invoice],@options[:password1],
                                             shp_fields_to_param ].flatten.join(':')) 
          @method_id = method_id.to_s.split("_").last.to_sym
          if valid_summa? && valid_invoice?
            send(@method_id)
          else
            false
          end
        else
          super
        end
      end
       # При проверке указываеться пароль2 на проверку результат
      def result(params)
        out_sum,invoice_id = params[:OutSum], params[:InvId]
        in_signature = params[:SignatureValue]
        params.each {|k,v| @custom_fields[k.to_sym] = v if k =~ /^shp/}
        signature = Digest::MD5.hexdigest([ out_sum,invoice_id, @options[:password2], 
                                            shp_fields_to_param].flatten.join(':')) 
        in_signature.upcase == signature.upcase ? true : false
      end
      
      alias :result? :result
       # при проверки положительно завершения используеться пароль1
      def success(params)
        out_sum,invoice_id = params[:OutSum], params[:InvId]
        in_signature = params[:SignatureValue]
        params.each {|k,v| @custom_fields[k.to_sym] = v if k =~ /^shp/}        
        signature = Digest::MD5.hexdigest([ out_sum,invoice_id, 
                                            @options[:password1],
                                            shp_fields_to_param ].flatten.join(':')) 
        in_signature.upcase == signature.upcase ? true : false
      end
      
      alias :success? :success
      
      # ==========================================================================================
      # XML - интерфейс
      # ==========================================================================================
      
      
      # Статус операции
      # invoice - номер платежа
      def state_operation(invoice)
        url = test? ? TEST_XML_URLS[:state_operation] : LIVE_XML_URLS[:state_operation]
        if invoice.is_a?(Integer) || invoice.is_a?(String)
          @invoice = invoice
        elsif invoice.is_a?(Hash) && invoice.has_key?(:InvId)
           @invoice = invoice[:InvId]
        else 
          false
        end
        
        signature = Digest::MD5.hexdigest([ @options[:login],@invoice, @options[:password2]].join(':'))    
        state_code = 100 if test?

        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'robox.opstate.req' do
          xml.tag! 'merchant_login', @options[:login]
          xml.tag! 'merchant_invid', @invoice
          xml.tag! 'crc', signature
          xml.tag!('state_code', state_code) if test?
        end

        result = http_post(url,xml.target!)
        
        status = { }
        xml = REXML::Document.new(result)

       elements =  REXML::XPath.first(xml, "robox.opstate.resp").root.elements
        status[:retval] = STATE_OPERATION_RET_CODE[elements[1].text]
        status[:date] = elements[2].text
        status[:out_curr] =elements[3].text
        status[:out_cnt] =elements[4].elements[1].text
        status[:state] = elements[4].elements[2].text
        status[:description] = STATE_OPERATION[elements[4].elements[2].text]

        return status
      end
      
      # списка курсов обмена
      def exchange_rate(options)
        url = test? ? TEST_XML_URLS[:exchange_rate] : LIVE_XML_URLS[:exchange_rate]
        out_count = options[:out_count] || 1
        merchant_login = @options[:login]
        inc_curr_label = options[:inc_curr] || ""
        out_curr_label = options[:out_curr] # required
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'robox.rate.req' do
          xml.tag! 'in_curr',inc_curr_label
          xml.tag! 'out_curr', out_curr_label
          xml.tag! 'merchant_login', merchant_login
          xml.tag! 'out_cnt', out_count
        end

        list = http_post(url,xml.target!)
        
        currency = { }
        xml = REXML::Document.new(list)

        elements =  REXML::XPath.first(xml, "robox.rate.resp").root.elements
        currency[:retval] = elements[1].text
        currency[:retval_description] = EXCHANGE_RATE_RET_CODE[elements[1].text]        
        currency[:out_curr_label] = elements[2].text
        currency[:out_cnt] = elements[3].text
        currency[:date] = elements[4].text
        currency[:rate_list] = [ ]
        rate_list = elements[5]
        rate_list.elements.each do |rate|
          currency[:rate_list] << { 
            :in_curr => rate.elements[1].text,
            :in_curr_name => rate.elements[2].text,
            :value => rate.elements[3].text,
            :in_count => rate.elements[4].text }
        end
        return currency
      end

      # список валют
      def currency
        url = test? ? TEST_XML_URLS[:list_currency] : LIVE_XML_URLS[:list_currency]
        list = http_get(url,{ })
        currency = []
        xml = REXML::Document.new(list)

        REXML::XPath.first(xml, "robox.currlist.resp").root.elements.each do |item|
          currency << { :curr => item.elements[1].text, :name => item.elements[2].text,} 
        end
        return currency
      end
      
     private
      
      def valid_invoice
        !@options[:invoice].nil? && !@options[:invoice].to_s.empty?
      end

      alias :valid_invoice? :valid_invoice
      
      def valid_summa
        !@options[:summa].nil? && !(@options[:summa] == 0) && (Kernel.Float(@options[:summa]) rescue false)
      end
      alias :valid_summa? :valid_summa
      
      def kassa
        url = test? ? TEST_HTML_KASSA_URL : LIVE_HTML_KASSA_URL                
        params = ["MrchLogin=#{@options[:login]}", "OutSum=#{@options[:summa]}",
                  "InvId=#{@options[:invoice]}", "IncCurrLabel=#{@options[:payment_currentcy]}",
                  "Desc=#{@options[:order_description]}", "SignatureValue=#{@options[:signature]}",
                  "Culture=#{@options[:language]}", "Encoding=#{@options[:encoding]}",
                  shp_fields_to_param ].flatten.join('&')
        src = [url, params].join('?')
        return  %{<script language=JavaScript src='#{src}'> </script>}        
      end
      
      def button
        url = test? ? TEST_PAYMENT_FORM_URL : LIVE_PAYMENT_FORM_URL
        submit = "<input type=submit value='#{@options[:value]}'>"
        params = [
                  "<input type=hidden name=MrchLogin value='#{@options[:login]}'",
                  "<input type=hidden name=OutSum value='#{@options[:summa]}'>",
                  "<input type=hidden name=InvId value='#{@options[:invoice]}'>",
                  "<input type=hidden name=Desc value='#{@options[:description]}'>",
                  "<input type=hidden name=SignatureValue value=#{@options[:signature]}>",
                  "<input type=hidden name=IncCurrLabel value=#{@options[:payment_currentcy]}>",
                  "<input type=hidden name=Culture value=#{@options[:language]}>",
                  shp_fields_to_html,
                  submit ].flatten.join()

        return %{ <form action='#{url}' method=POST>#{params}</form>}        
      end 
      
      def shp_fields_to_html
        @custom_fields.collect{ |k,v| "<input type=hidden name='#{k}' value='#{v}'>" }
      end
      
      def shp_fields_to_param
        str =  @custom_fields.keys.collect{|x| x.to_s}.sort.
          collect {|x| "#{x}=#{@custom_fields[x.to_sym]}" } 
        raise "Слишком много пользовательских параметров. Должно быть не больше 2048 знаков." if str.size >= 2048
        return str
      end
    end
  end
end

