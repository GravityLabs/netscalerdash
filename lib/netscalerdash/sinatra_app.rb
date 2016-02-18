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

      @ns_connections = {}
      @netscalers.each do |ns|
        @ns_connections[ns] = Netscaler::Connection.new hostname: ns,
                                                              username: @nitro_username,
                                                              password: @nitro_password,
                                                              verify_ssl: @verify_ssl
      end
    end

    get '/' do
      # @message = 'Hello World!'
      # erb :home

      @ns = {}
      @ns_connections.keys.each do |ns|
        @ns[ns] = {'lb' => @ns_connections[ns].lb.vserver.stat['lbvserver'],
                   'cs' => @ns_connections[ns].cs.vserver.stat['csvserver']}
      end

      erb :netscalers
    end

    get '/netscalers' do

      @ns = {}
      @ns_connections.keys.each do |ns|
        @ns[ns] = {'lb' => @ns_connections[ns].lb.vserver.stat['lbvserver'],
                   'cs' => @ns_connections[ns].cs.vserver.stat['csvserver']}
      end

      erb :netscalers
    end

    get '/ns/:netscaler' do
      @ns = {}
      ns = params[:netscaler]
      @ns[ns] = {'lb' => @ns_connections[ns].lb.vserver.stat['lbvserver'],
                 'cs' => @ns_connections[ns].cs.vserver.stat['csvserver']}
      erb :netscalers
    end

    get '/ns/:netscaler/:service' do
      @netscaler = params[:netscaler]
      servicename = params[:service]
      @service = @ns_connections[@netscaler].service.show serviceName: servicename
      @service_bindings
    end

    get '/ns/:netscaler/:type/:vserver/bindings' do
      @netscaler = params[:netscaler]
      vserver = params[:vserver]
      @type = params[:type]
      @bindings = @ns_connections[@netscaler].send(@type).vserver.show_binding name: vserver

      threads = []
      @policies = {'cspolicy' => [], 'rewritepolicy' => [], 'responderpolicy' => []}
      entity_types = {'cspolicy' => 'cs', 'responderpolicy' => 'responder', 'rewritepolicy' => 'rewrite'}
      policies_mutex = Mutex.new

      @bindings['lbvserver_binding'][0].keys.each do |bindings|
        next if bindings =~ /name|lbvserver_service_binding/
        #$logger.info(bindings)
        entity_type = bindings.match(/^.*_(.*)_.*$/)[1]
        entity_type = 'cspolicy' if entity_type == 'csvserver'
        $logger.info(entity_type)

        @bindings['lbvserver_binding'][0][bindings].each do |b|
          # $logger.info("fetching policy #{b['policyname']}")
          # policies[entity_type] << @ns_connections[@netscaler].send(entity_types[entity_type]).policy.show(name: b['policyname'])

          threads << Thread.new(b, @policies) do |b, policies|
            $logger.info("fetching policy #{b['policyname']}")
            policy = @ns_connections[@netscaler].send(entity_types[entity_type]).policy.show(name: b['policyname'])
            policies_mutex.synchronize { policies[entity_type] << policy }
            $logger.info("Done: #{b['policyname']}")
          end
        end
        threads.each(&:join)
        $logger.info('Done with all')

      end

      erb :bindings
    end

    get '/ns/:netscaler/:type/:vserver' do
      @netscaler = params[:netscaler]
      vserver = params[:vserver]
      type = params[:type]
      @vserver = @ns_connections[@netscaler].send(type).vserver.stat name: vserver
      @bindings = @ns_connections[@netscaler].send(type).vserver.show_binding name: vserver
      if type == 'cs'
        all_cs_policies = @ns_connections[@netscaler].cs.policy.show
        @cs_policies = {}
        all_cs_policies['cspolicy'].each do |cs|
          @cs_policies[cs['policyname']] = cs
        end
      end
      erb :"#{type}vserver"
    end

  end
end
