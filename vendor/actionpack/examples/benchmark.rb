$:.unshift(File.dirname(__FILE__) + "/../lib")

require "action_controller"
require 'action_controller/test_process'

Person = Struct.new("Person", :name)

class BenchmarkController < ActionController::Base
  def message
    render_text "hello world"
  end

  def list
    @people = [ Person.new("David"), Person.new("Mary") ]
    render_template "hello: <% for person in @people %>Name: <%= person.name %><% end %>"
  end
end

#ActionController::Base.template_root = File.dirname(__FILE__)

require "benchmark"

RUNS = ARGV[0] ? ARGV[0].to_i : 50

require "profile" if ARGV[1]

runtime = Benchmark.measure {
  RUNS.times { BenchmarkController.process_test(ActionController::TestRequest.new({ "action" => "list" })) }
}

puts "List: #{RUNS / runtime.real}"


runtime = Benchmark.measure {
  RUNS.times { BenchmarkController.process_test(ActionController::TestRequest.new({ "action" => "message" })) }
}

puts "Message: #{RUNS / runtime.real}"
