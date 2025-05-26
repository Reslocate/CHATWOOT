/* global axios */

import ApiClient from '../ApiClient';

/**
 * Represents the data object for a Deepseek hook.
 * @typedef {Object} ConversationMessageData
 * @property {string} [content] - The content of the message.
 * @property {string} [conversation_display_id] - The display ID of the conversation (optional).
 */

/**
 * A client for the Deepseek API.
 * @extends ApiClient
 */
class DeepseekAPI extends ApiClient {
  /**
   * Creates a new DeepseekAPI instance.
   */
  constructor() {
    super('integrations/deepseek', { accountScoped: true });

    /**
     * The conversation events supported by the API.
     * @type {string[]}
     */
    this.conversation_events = [
      'summarize',
      'reply_suggestion',
      'label_suggestion',
    ];

    /**
     * The message events supported by the API.
     * @type {string[]}
     */
    this.message_events = ['rephrase'];
  }

  /**
   * Processes an event using the Deepseek API.
   * @param {Object} options - The options for the event.
   * @param {string} [options.type='rephrase'] - The type of event to process.
   * @param {string} [options.content] - The content of the event.
   * @param {string} [options.conversationId] - The ID of the conversation to process the event for.
   * @param {string} options.hookId - The ID of the hook to use for processing the event.
   * @returns {Promise} A promise that resolves with the result of the event processing.
   */
  async processEvent({ type = 'rephrase', content, conversationId, hookId }) {
    /**
     * @type {ConversationMessageData}
     */
    let data = {
      content,
    };

    if (this.conversation_events.includes(type)) {
      data = {
        conversation_display_id: conversationId,
      };
    }

    try {
      const response = await axios.post(`${this.url}/hooks/${hookId}/process_event`, {
        event: {
          name: type,
          data,
        },
      });
      return { success: true, data: response.data };
    } catch (error) {
      console.error('DeepSeek API error:', error);
      
      // Enhanced error logging
      if (error.response) {
        console.error('Response data:', error.response.data);
        console.error('Response status:', error.response.status);
      }
      
      return {
        success: false,
        error: error.response?.data?.message || 'Failed to connect to DeepSeek API',
        message: error.response?.data?.message || 'Failed to connect to DeepSeek API'
      };
    }
  }

  /**
   * Generates AI suggestions using DeepSeek
   * @param {number} accountId - The account ID
   * @param {Object} params - Request parameters
   * @returns {Promise} Promise with response or error
   */
  async generateSuggestion(accountId, params, retries = 2) {
    console.group('DeepSeek API Connection Debug');
    console.log('Endpoint:', `${this.url}/${accountId}/integrations/deepseek/generate`);
    console.log('API Key:', this.maskApiKey(params.api_key));
    console.log('Params:', {
      ...params,
      api_key: '***' // Mask sensitive data
    });

    // Track API call metrics
    const startTime = Date.now();
    let attemptCount = 0;
    let success = false;
    let errorType = null;

    try {
      // First check API connectivity with retries
      let pingResponse;
      let attempt = 0;
      while (attempt <= retries) {
        try {
          pingResponse = await axios.get(`${this.url}/${accountId}/integrations/deepseek/status`, {
            timeout: 5000,
            headers: {
              'Authorization': `Bearer ${params.api_key}`,
              'X-Debug-Connection': 'true'
            }
          });
          break;
        } catch (pingError) {
          attempt++;
          if (attempt > retries) throw pingError;
          console.warn(`Connection check failed (attempt ${attempt}), retrying...`);
          await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
        }
      }
      console.log('Connection Status:', pingResponse.status, pingResponse.data);

      // Main request with retries
      let response;
      attempt = 0;
      while (attempt <= retries) {
        try {
          response = await axios.post(
            `${this.url}/${accountId}/integrations/deepseek/generate`,
            params,
            {
              timeout: 15000,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${params.api_key}`
              }
            }
          );
          break;
        } catch (reqError) {
          attempt++;
          if (attempt > retries) throw reqError;
          console.warn(`Request failed (attempt ${attempt}), retrying...`);
          await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
        }
      }
      
      console.log('API Response:', response.status, response.data);
      success = true;
      return {
        success: true,
        data: response.data,
        message: this.extractMessage(response.data),
        metrics: {
          durationMs: Date.now() - startTime,
          attempts: attemptCount,
          endpoint: `${this.url}/${accountId}/integrations/deepseek/generate`
        }
      };
    } catch (error) {
      console.error('API Error:', error);
      if (error.response) {
        console.error('Response:', error.response.status, error.response.data);
      } else if (error.request) {
        console.error('Request:', error.request);
      } else {
        console.error('Error:', error.message);
      }
      
      errorType = this.getErrorType(error);
      return {
        success: false,
        error: this.extractErrorMessage(error),
        message: this.extractErrorMessage(error),
        details: error.response?.data || error.message,
        metrics: {
          durationMs: Date.now() - startTime,
          attempts: attemptCount,
          errorType: errorType,
          endpoint: `${this.url}/${accountId}/integrations/deepseek/generate`
        }
      };
    } finally {
      console.groupEnd();
    }
  }

  maskApiKey(key) {
    if (!key || key.length < 8) return '***';
    return `${key.substring(0, 4)}...${key.substring(key.length - 4)}`;
  }

  extractMessage(data) {
    if (typeof data === 'string') return data;
    if (data?.message) return data.message;
    if (data?.content) return data.content;
    if (data?.choices?.[0]?.message?.content) return data.choices[0].message.content;
    return JSON.stringify(data);
  }

  extractErrorMessage(error) {
    if (error.response?.data?.error) return error.response.data.error;
    if (error.response?.data?.message) return error.response.data.message;
    if (error.message) return error.message;
    return 'Failed to connect to DeepSeek API';
  }

  getErrorType(error) {
    if (!error.response) {
      return error.code || 'network_error';
    }
    switch (error.response.status) {
      case 400: return 'bad_request';
      case 401: return 'unauthorized';
      case 403: return 'forbidden';
      case 404: return 'not_found';
      case 429: return 'rate_limited';
      case 500: return 'server_error';
      case 502: return 'bad_gateway';
      case 503: return 'service_unavailable';
      case 504: return 'gateway_timeout';
      default: return `http_${error.response.status}`;
    }
  }
}

export default new DeepseekAPI();