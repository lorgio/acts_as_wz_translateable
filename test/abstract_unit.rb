# Take from acts_as_versioned http://github.com/technoweenie/acts_as_versioned/blob/master/test/abstract_unit.rb
$:.unshift(File.dirname(__FILE__) + '/../../../rails/activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../../../rails/activerecord/lib')
$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'test/unit'
begin
  require 'active_record'
  require 'active_record/fixtures'
rescue LoadError
  require 'rubygems'
  retry
end

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end

require 'acts_as_wz_translateable'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.configurations = {'test' => config[ENV['DB'] || 'sqlite3']}
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])

load(File.dirname(__FILE__) + "/schema.rb")

# Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
# $:.unshift(Test::Unit::TestCase.fixture_path)

class Test::Unit::TestCase #:nodoc:
  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  # self.use_transactional_fixtures = true
  # 
  # # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  # self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
  
end