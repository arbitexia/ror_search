require 'spec_helper'

describe TXOIGRefreshJob do
  describe 'when fails' do
    it 'should send an email to all admins' do
      allow_any_instance_of(TXOIGSearcher).to receive(:download_latest_tsv).and_raise('some fake error')
      # make sure the method is raising an error
      expect do
        TXOIGSearcher.download_latest_tsv
      end.to raise_error('some fake error')
      # error should be rethrown after being caught in the refresh job
      expect do
        TXOIGRefreshJob.new.perform
      end.to raise_error('some fake error')
      expect(ActionMailer::Base.deliveries.count).to eq 1 # an email should have been sent to admins

      failure_email = ActionMailer::Base.deliveries.first
      expect(failure_email.subject).to include 'Texas OIG'
      expect(failure_email.to).to eq ENV['ADMIN_EMAILS'].split(',')
    end
  end
end
