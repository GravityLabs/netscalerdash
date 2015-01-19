class Netscalerdash
  class SinatraApp < ::Sinatra::Base
    def initialize(netscalers, nitro_username, nitro_password, verify_ssl)
      @netscalers = netscalers
      @nitro_username = nitro_username
      @nitro_password = nitro_password
      @verify_ssl = verify_ssl
      super()
    end

    register Sinatra::StaticAssets

    configure :production do
      logdir = File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'log')
      Dir.mkdir(logdir) unless File.exist?(logdir)
      $logger = Logger.new(logdir + '/netscalerdash.log','weekly')
      $logger.level = Logger::INFO
    end

    configure :development do
      $logger = Logger.new(STDOUT)
    end

    configure :test do
      $logger = Logger.new(NIL)
    end

    configure do
      set :views, File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'views')
      set :static, true
      set :public_folder, File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'public')
    end

    before do
      logdir = File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'log')
      Dir.mkdir(logdir) unless File.exist?(logdir)
    end

    get '/' do
      @message = 'Hello World!'
      erb :home
    end

  end
end
