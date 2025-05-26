




require_relative '../config/environment'
require 'benchmark'

class ClaudeIntegrationTester
  API_KEY = ENV['CLAUDE_API_KEY']
  TEST_CONVERSATION = {
    message: OpenStruct.new(content: "How do I reset my password?"),
    conversation_context: "Customer is having login issues",
    event: "reply_suggestion"
  }

  def initialize
    @hook = OpenStruct.new(
      settings: { 'api_key' => API_KEY },
      account_id: 'test_account'
    )
    @service = Integrations::Claude::ProcessorService.new(
      hook: @hook,
      event: TEST_CONVERSATION
    )
  end

  def run_full_test
    puts "=== Claude Integration Diagnostic Test ==="
    test_connection
    test_performance
    test_error_handling
    test_rate_limiting
    puts "=== Test Complete ==="
  end

  private

  def test_connection
    puts "\n[1/4] Testing API Connection..."
    response = @service.perform
    if response.success?
      puts "✅ Success - Received valid response"
      puts "Response: #{JSON.parse(response.body)['content'].first['text']}"
    else
      puts "❌ Failed - #{response.code}: #{response.message}"
    end
  end

  def test_performance
    puts "\n[2/4] Testing Performance..."
    times = Benchmark.measure { 5.times { @service.perform } }
    puts "Average response time: #{(times.real / 5).round(2)}s"
  end

  def test_error_handling
    puts "\n[3/4] Testing Error Handling..."
    
    # Test invalid API key
    invalid_service = Integrations::Claude::ProcessorService.new(
      hook: OpenStruct.new(settings: { 'api_key' => 'invalid' }),
      event: TEST_CONVERSATION
    )
    begin
      invalid_service.perform
      puts "❌ Failed - Should reject invalid API key"
    rescue => e
      puts "✅ Success - Caught invalid key: #{e.message}"
    end

    # Test timeout
    ENV['CLAUDE_REQUEST_TIMEOUT'] = '0.001'
    begin
      @service.perform
      puts "❌ Failed - Should timeout"
    rescue Net::ReadTimeout
      puts "✅ Success - Caught timeout"
    ensure
      ENV.delete('CLAUDE_REQUEST_TIMEOUT')
    end
  end

  def test_rate_limiting
    puts "\n[4/4] Testing Rate Limiting..."
    puts "Note: Run this test separately with CLAUDE_API_KEY set"
    puts "Manual verification needed for rate limit headers"
  end
end

ClaudeIntegrationTester.new.run_full_test if __FILE__ == $0