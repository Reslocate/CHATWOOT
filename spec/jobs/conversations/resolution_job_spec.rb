require 'rails_helper'

RSpec.describe Conversations::ResolutionJob do
  subject(:job) { described_class.perform_later(account: account) }

  let!(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account) }

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(account: account)
      .on_queue('low')
  end

  it 'does nothing when there is no auto resolve duration' do
    described_class.perform_now(account: account)
    expect(conversation.reload.status).to eq('open')
  end

  it 'resolves the issue if time of inactivity is more than the auto resolve duration' do
    account.update(auto_resolve_after: 14_400) # 10 days in minutes
    conversation.update(last_activity_at: 13.days.ago, waiting_since: nil)
    described_class.perform_now(account: account)
    expect(conversation.reload.status).to eq('resolved')
  end

  it 'resolved only a limited number of conversations in a single execution' do
    stub_const('Limits::BULK_ACTIONS_LIMIT', 2)
    account.update(auto_resolve_after: 14_400) # 10 days in minutes
    conversations = create_list(:conversation, 3, account: account, last_activity_at: 13.days.ago)
    conversations.each { |conversation| conversation.update(waiting_since: nil) }
    described_class.perform_now(account: account)
    expect(account.conversations.resolved.count).to eq(Limits::BULK_ACTIONS_LIMIT)
  end
end
