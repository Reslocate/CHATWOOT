FactoryBot.define do
  factory :integrations_hook, class: 'Integrations::Hook' do
    account
    inbox
    app_id { 'slack' }
    hook_type { 'account' }
    status { 'enabled' }

    trait :deepseek do
      app_id { 'deepseek' }
      settings { { api_key: ENV.fetch('DEEPSEEK_API_KEY') } }
    end
  end
end
