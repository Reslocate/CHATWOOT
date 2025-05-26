module Api::V1::Accounts::Integrations::Deepseek::Hooks::Openai
  class ProcessEventController < ApplicationController
    def create
      begin
        Rails.logger.info("DeepSeek process_event called")
        
        # Get conversation context
        conversation_id = params.dig(:event, :data, :conversation_display_id)
        
        # In a real implementation, you'd fetch conversation content
        # Here's a simplified prompt
        prompt = "Please provide a brief, helpful customer support response."
        
        # Call DeepSeek API
        require 'net/http'
        uri = URI('https://api.deepseek.com/v1/chat/completions')  # Check if this is the correct endpoint
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        
        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['DEEPSEEK_API_KEY'] || 'default_key'}"
        })
        
        request.body = {
          model: 'deepseek-chat',  # Verify this is the correct model name
          messages: [
            { role: 'system', content: 'You are a helpful customer support assistant.' },
            { role: 'user', content: prompt }
          ]
        }.to_json
        
        Rails.logger.info("Calling DeepSeek API...")
        response = http.request(request)
        Rails.logger.info("DeepSeek API response code: #{response.code}")
        Rails.logger.info("DeepSeek API response body: #{response.body[0..200]}...")  # Log first 200 chars
        
        if response.code.to_i == 200
          result = JSON.parse(response.body)
          suggestion = result.dig('choices', 0, 'message', 'content')
          render plain: suggestion, content_type: 'text/plain'
        else
          Rails.logger.error("DeepSeek API error: #{response.body}")
          render plain: "Sorry, I couldn't generate a suggestion. API response: #{response.code}", content_type: 'text/plain'
        end
        
      rescue StandardError => e
        Rails.logger.error("DeepSeek API error: #{e.message}")
        Rails.logger.error("#{e.backtrace.join("\n")}")
        render plain: "I couldn't generate a suggestion due to an error.", content_type: 'text/plain'
      end
    end
  end
end