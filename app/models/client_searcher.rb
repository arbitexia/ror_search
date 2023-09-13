class ClientSearcher < ApplicationRecord
  belongs_to :client

  scope :enabled, -> { where(enabled: true) }

  class << self
    def employee_searcher_source
      {
        'AL - CNA' => ALCNASearcher,
        'AR - DHS' => DHSARSearcher,
        'LA - ADRA' => LaAdraSearcher,
        'LA - LDH Adverse Actions' => DHHSearcher,
        'LA - CNA' => DSWSearcher,
        'LA - State Board of Medical Examiners (only when LA License # present)' => LSBMESearcher,
        'MS - Medicaid' => MSMedicaidSearcher,
        'OFAC' => OFACSearcher,
        'OIG' => OIGSearcher,
        'PA - DHS Medicheck' => PAMedicheckSearcher,
        'SAM' => SAMSearcher,
        'TMU - Arkansas Misconduct Registry' => TmuArkansasSearcher,
        'TX - DADS' => DADSEMRSearcher,
        'TX - Medical Board (only when TX License # present)' => TMBSearcher,
        'TX - OIG' => TXOIGSearcher
      }
    end

    def vendor_searchers
      [OIGSearcher, SAMSearcher, DHHSearcher, DHSARSearcher, MSMedicaidSearcher, TXOIGSearcher,
       PAMedicheckSearcher, LSBMESearcher, TMBSearcher, OFACSearcher, LaAdraSearcher]
    end

    def vendor_searcher_source
      employee_searcher_source.select do |_, searcher|
        vendor_searchers.include?(searcher)
      end
    end

    # for use in select fields / user facing stuff
    def employee_searcher_collection
      Hash[employee_searcher_source.map { |pair| [pair.first, pair.last.to_s] }]
    end

    def vendor_searcher_collection
      Hash[vendor_searcher_source.map { |pair| [pair.first, pair.last.to_s] }]
    end

    # use this to look up names of searchers from their class name
    def reverse_searcher_map
      Hash[employee_searcher_source.map { |pair| [pair.last.to_s, pair.first] }]
    end
  end

  enumerize :searcher, in: begin
    mapped_array = employee_searcher_source.values.map.with_index { |value, index| [value.to_s, index] }
    Hash[mapped_array]
  end

  def searcher_url
    {
      'ALCNASearcher' => 'https://dph1.adph.state.al.us/NurseAideRegistry',
      'DHSARSearcher' => 'https://dhs.arkansas.gov/dhs/portal/Exclusions/PublicSearch/',
      'LaAdraSearcher' => 'https://la-adra.org/disciplinary-actions/',
      'DHHSearcher' => 'https://adverseactions.ldh.la.gov/SelSearch',
      'DSWSearcher' => 'https://tlc.dhh.la.gov',
      'LSBMESearcher' => 'https://www.lsbme.la.gov/content/verifications',
      'MSMedicaidSearcher' => 'https://medicaid.ms.gov/providers/provider-terminations/',
      'OFACSearcher' => 'https://sanctionssearch.ofac.treas.gov/',
      'OIGSearcher' => 'https://oig.hhs.gov',
      'PAMedicheckSearcher' => 'https://www.humanservices.state.pa.us/Medchk/MedchkSearch/Index',
      'SAMSearcher' => 'https://sam.gov',
      'TmuArkansasSearcher' => 'https://ar.tmuniverse.com/search',
      'DADSEMRSearcher' => 'https://emr.dads.state.tx.us/DadsEMRWeb/emrRegistrySearch.jsp',
      'TMBSearcher' => 'http://www.tmb.state.tx.us/page/look-up-a-license',
      'TXOIGSearcher' => 'https://oig.hhsc.state.tx.us/oigportal2/Exclusions'
    }[searcher]
  end
end
