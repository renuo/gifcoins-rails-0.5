require File.dirname(__FILE__) + '/../abstract_unit'

class FlashTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["that"] = "hello"
    end

    def use_flash
      @flashy = flash["that"]
    end

    def use_flash_and_keep_it
      @flashy = flash["that"]
      keep_flash
    end

    def rescue_action(e)
      raise unless ActionController::MissingTemplate === e
    end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_flash
    @request.action = "set_flash"
    response = process_request
    
    @request.action = "use_flash"
    first_response = process_request
    assert_equal "hello", first_response.template.assigns["flash"]["that"]
    assert_equal "hello", first_response.template.assigns["flashy"]

    second_response = process_request
    assert_nil second_response.template.assigns["flash"]["that"], "On second flash"
  end

  def test_keep_flash
    @request.action = "set_flash"
    response = process_request
    
    @request.action = "use_flash_and_keep_it"
    first_response = process_request
    assert_equal "hello", first_response.template.assigns["flash"]["that"]
    assert_equal "hello", first_response.template.assigns["flashy"]

    @request.action = "use_flash"
    second_response = process_request
    assert_equal "hello", second_response.template.assigns["flash"]["that"], "On second flash"

    third_response = process_request
    assert_nil third_response.template.assigns["flash"]["that"], "On third flash"
  end
  
  private
    def process_request
      TestController.process(@request, @response)
    end
end