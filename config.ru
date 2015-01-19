$: << File.join(File.dirname(__FILE__), 'lib')

tmpdir = File.join(File.dirname(__FILE__), 'tmp')
ENV['TMPDIR'] = tmpdir
Dir.mkdir(tmpdir) unless File.exist?(tmpdir)

require 'bundler/setup'
require 'netscalerdash'
config = YAML.load_file(File.expand_path('../config/netscalerdash.yaml', __FILE__))

#run Sinatra::Application
run Netscalerdash::SinatraApp.new(config[:netscalers], config[:nitro_username], config[:nitro_password], config[:verify_ssl])
