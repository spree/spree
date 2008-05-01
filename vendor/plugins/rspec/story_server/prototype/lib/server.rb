require 'webrick'

class DispatchServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request, response)
    File.open('story', 'w') do |io|
      io.write(request.body)
    end

    response.status = 200
    response['Content-Type'] = 'text/html'
    response.body = "body"
  end
end

params = { :Port        => 4000,
           :ServerType  => WEBrick::SimpleServer,
           :BindAddress => "0.0.0.0",
           :MimeTypes   => WEBrick::HTTPUtils::DefaultMimeTypes }
server = WEBrick::HTTPServer.new(params)
server.mount('/stories', DispatchServlet)
server.mount('/', WEBrick::HTTPServlet::FileHandler, File.dirname(__FILE__) + '/..', { :FancyIndexing => true })

trap("INT") { server.shutdown }
server.start