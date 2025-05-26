# DeepSeek Integration Guide

## Overview
The DeepSeek integration provides AI-powered conversation assistance using DeepSeek's API. Key features:
- Reply suggestions
- Conversation summarization
- Sentiment analysis
- Domain-specific processing

## Architecture
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Processor      │────▶│  Base Service   │────▶│  DeepSeek API   │
│  Service        │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
       ▲                       ▲
       │                       │
┌─────────────────┐     ┌─────────────────┐
│  Monitoring     │     │  Configuration  │
│  & Analytics    │     │  (ENV vars)     │
└─────────────────┘     └─────────────────┘
```

## Configuration
Environment variables:
- `DEEPSEEK_API_URL`: API endpoint (default: `https://api.deepseek.com/v1/chat/completions`)
- `DEEPSEEK_MODEL`: Model to use (default: `deepseek-pro`)
- `DEEPSEEK_TOKEN_LIMIT`: Max tokens per request (default: `500000`)
- `DEEPSEEK_REQUEST_TIMEOUT`: Request timeout in seconds (default: `30`)
- `DEEPSEEK_MAX_RETRIES`: Max retry attempts (default: `2`)
- `DEEPSEEK_RETRY_DELAY`: Base retry delay in seconds (default: `0.5`)

## Production Considerations

### Rate Limiting
The integration implements:
- Exponential backoff retries
- Circuit breaker pattern (5 failures opens circuit for 60s)
- Priority-based rate limiting headers
- Real-time monitoring of rate limits

### Monitoring
Key metrics tracked:
- API response times
- Error rates
- Rate limit utilization
- Token usage

View metrics in Datadog under:
- `deepseek.integration.*`
- `deepseek.rate_limit.*`

## Development Guide

### Testing
Run the complete test suite:
```bash
bundle exec rspec spec/services/integrations/deepseek/
```

Key test files:
- `processor_service_spec.rb` - Core functionality
- `monitoring_spec.rb` - Analytics and metrics

### Adding New Features
1. Extend `DeepseekBaseService` for shared functionality
2. Create new processor service for specific features
3. Add monitoring calls using `Integrations::Deepseek::Monitoring`
4. Write comprehensive tests

## Troubleshooting

### Common Issues
**API Timeouts**:
- Check `DEEPSEEK_REQUEST_TIMEOUT` value
- Verify network connectivity to DeepSeek API

**Rate Limiting**:
- Monitor `X-RateLimit-Remaining` headers
- Consider reducing request frequency
- Use priority headers for critical requests

**Authentication Errors**:
- Verify API key in hook settings
- Check key rotation schedule