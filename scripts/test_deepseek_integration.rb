require_relative '../config/environment'

# Initialize test data using existing records where possible
include FactoryBot::Syntax::Methods

account = Account.first || begin
  timestamp = Time.now.to_i
  FactoryBot.create(:account, name: "Test Account #{timestamp}").tap do |acc|
    # Create user with unique email
    FactoryBot.create(:user,
      account: acc,
      email: "testuser-#{timestamp}@example.com"
    )
  end
end

puts "\nUsing API key: #{ENV['DEEPSEEK_API_KEY']}"
api_key = ENV.fetch('DEEPSEEK_API_KEY')
puts "API key length: #{api_key.length}"
puts "API key prefix: #{api_key[0..6]}"

hook = Integrations::Hook.deepseek.first
if hook
  hook.settings['api_key'] = api_key
  hook.save!
  puts "Updated hook settings: #{hook.settings}"
else
  hook = Integrations::Hook.create!(
    app_id: 'deepseek',
    account: account,
    settings: {
      'account_id' => "test-#{Time.now.to_i}",
      'api_key' => api_key
    }
  )
  puts "Created hook settings: #{hook.settings}"
end
hook

puts "Hook settings: #{hook.settings.inspect}"
puts "Actual API key being used: #{hook.settings['api_key']}"

conversation = account.conversations.first || FactoryBot.create(:conversation, account: account)
customer_message = FactoryBot.create(:message, account: account, conversation: conversation,
                          message_type: :incoming, content: 'Hello, I need help with my order')
agent_message = FactoryBot.create(:message, account: account, conversation: conversation,
                       message_type: :outgoing, content: 'Hello, what is your order number?')

# Test rephrase feature
puts "\nTesting rephrase:"
rephrase_event = {
  'name' => 'rephrase',
  'data' => {
    'content' => 'Your order is delayed'
  }
}
puts "Input: #{rephrase_event.inspect}"
rephrase_processor = Integrations::Deepseek::ProcessorService.new(
  hook: hook,
  event: rephrase_event
)
rephrase_result = rephrase_processor.perform
puts "API Response: #{rephrase_result.inspect}"
puts "Rephrased result: #{rephrase_result[:message]}"

# Test summarize feature
puts "\nTesting summarize:"
summarize_event = {
  'name' => 'summarize',
  'data' => {
    'conversation_display_id' => conversation.display_id,
    'messages' => [
      {content: customer_message.content},
      {content: agent_message.content}
    ]
  }
}
puts "Input: #{summarize_event.inspect}"
summarize_processor = Integrations::Deepseek::ProcessorService.new(
  hook: hook,
  event: summarize_event
)
summarize_result = summarize_processor.perform
puts "API Response: #{summarize_result.inspect}"
puts "Summary result: #{summarize_result[:message]}"

# Test reply suggestion feature
puts "\nTesting reply suggestion:"
reply_event = {
  'name' => 'reply_suggestion',
  'data' => {
    'conversation_display_id' => conversation.display_id,
    'messages' => [
      {content: customer_message.content},
      {content: agent_message.content}
    ]
  }
}
puts "Input: #{reply_event.inspect}"
reply_processor = Integrations::Deepseek::ProcessorService.new(
  hook: hook,
  event: reply_event
)
reply_result = reply_processor.perform
puts "API Response: #{reply_result.inspect}"
puts "Reply suggestion: #{reply_result[:message]}"

puts "\nDeepseek integration tests completed!"