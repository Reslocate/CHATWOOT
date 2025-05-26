require 'rails_helper'

RSpec.describe Integrations::Deepseek::ProcessorService do
  subject { described_class.new(hook: hook, event: event) }

  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :deepseek, account: account) }
  let(:expected_headers) do
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => "Bearer #{hook.settings['api_key']}",
      'Content-Type' => 'application/json',
      'User-Agent' => 'Ruby'
    }
  end
  let(:deepseek_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'This is a reply from deepseek.'
          }
        }
      ]
    }.to_json
  end
  let!(:conversation) { create(:conversation, account: account) }
  let!(:customer_message) { create(:message, account: account, conversation: conversation, message_type: :incoming, content: 'hello agent') }
  let!(:agent_message) { create(:message, account: account, conversation: conversation, message_type: :outgoing, content: 'hello customer') }
  let!(:summary_prompt) do
    if ChatwootApp.enterprise? && File.exist?(Rails.root.join('enterprise/lib/enterprise/integrations/deepseek_prompts/summary.txt'))
      Rails.root.join('enterprise/lib/enterprise/integrations/deepseek_prompts/summary.txt').read
    else
      'Summarize the key points from this customer support conversation in 3-5 bullet points. Include:\\n' \
      "- The customer's main issue\\n" \
      "- Any solutions attempted\\n" \
      "- Current status\\n" \
      "- Next steps if mentioned\\n\\n" \
      "Keep the summary concise and professional. Use the same language as the conversation.\\n\\n" \
      "Conversation History:\\n" \
      "{{conversation_messages}}\\n\\n" \
      "Summary:\\n" \
      "• \\n" \
      "• \\n" \
      "•"
    end
  end

  describe '#perform' do
    context 'when event name is rephrase' do
      let(:event) { { 'name' => 'rephrase', 'data' => { 'tone' => 'friendly', 'content' => 'This is a test message' } } }

      it 'returns the rephrased message using the tone in data' do
        request_body = {
          'model' => 'deepseek-pro',
          'messages' => [
            {
              'role' => 'system',
              'content' => 'You are a helpful support agent. ' \
                           'Please rephrase the following response. ' \
                           'Ensure that the reply should be in user language.'
            },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.deepseek.com/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: deepseek_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from deepseek.' })
      end
    end

    context 'when event name is reply_suggestion' do
      let(:event) { { 'name' => 'reply_suggestion', 'data' => { 'conversation_display_id' => conversation.display_id } } }

      it 'returns the suggested reply' do
        request_body = {
          'model' => 'deepseek-pro',
          'messages' => [
            { role: 'system',
              content: Rails.root.join('lib/integrations/deepseek/deepseek_prompts/reply.txt').read },
            { role: 'user', content: customer_message.content },
            { role: 'assistant', content: agent_message.content }
          ]
        }.to_json

        stub_request(:post, 'https://api.deepseek.com/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: deepseek_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from deepseek.' })
      end
    end

    context 'when event name is summarize' do
      let(:event) { { 'name' => 'summarize', 'data' => { 'conversation_display_id' => conversation.display_id } } }
      let(:conversation_messages) do
        "Customer #{customer_message.sender.name} : #{customer_message.content}\nAgent #{agent_message.sender.name} : #{agent_message.content}\n"
      end

      it 'returns the summarized message' do
        request_body = {
          'model' => 'deepseek-pro',
          'messages' => [
            { 'role' => 'system',
              'content' => summary_prompt.gsub('\\n', "\n") },
            { 'role' => 'user', 'content' => conversation_messages }
          ]
        }.to_json

        stub_request(:post, 'https://api.deepseek.com/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: deepseek_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from deepseek.' })
      end
    end

    # Additional test contexts (fix_spelling_grammar, shorten, expand, etc.)
    # would follow the same pattern as above, replacing OpenAI with DeepSeek
  end
end