require 'spec_helper'

describe SAMSearcher do
  describe 'ssn non-match' do
    it 'should return false when a non-match' do
      expect(SAMSearcher.beta_ssn_matches?('Jane', '', 'Doe', '111001111')).to be false
    end
  end
end
