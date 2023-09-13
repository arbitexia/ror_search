require 'csv'

module PAMedicheckSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'PAMedicheck'
  end

  def db_refresh_url
    'http://services.dpw.state.pa.us/dhs/medicheck.txt'
  end

  def search_employee(employee)
    # "ProviderName","LicenseNumber","Status","BeginDate","EndDate","CAO","ListDate","IND_CHGD","DTE_CHANGE_LAST","NAM_LAST_PROVR","NAM_FIRST_PROVR","NAM_MIDDLE_PROVR","NAM_TITLE_PROVR","NAM_SUFFIX_PROVR","NAM_PROVR_ALT","NAM_BUSNS_MP","IDN_NPI"
    # ProviderName is always "Last, First" followed by possible middle initial followed by possible title/tag
    #
    # then we have a status, begin date, end date, and list date
    # if present we can supply license number and/or NPI number
    results = search(employee.last_name_clean, employee.first_name_clean, employee.middle_name_clean)

    results.each do |result|
      row = result[:row]
      details = 'Flagged on PA DHS Medicheck List as: '
      details += row['providername']
      details += "\n"

      details += "Status: #{row['status']}"
      details += "\n"

      details += "Begin date: #{row['begindate']}"
      details += "\n"

      details += "End date: #{row['enddate']}"
      details += "\n"

      details += "List date: #{row['listdate']}"
      details += "\n"

      if row['license_number'].present?
        details += "License number: #{row['licensenumber']}"
        details += "\n"
      end

      if row['idn_npi'].present?
        details += "NPI number: #{row['idn_npi']}"
        details += "\n"
      end

      details += 'Date of Birth was not checked'
      details += "\n"

      details += 'SSN was not checked'
      details += "\n"

      result[:details] = details
      result[:first] = row['first_name']
      result[:last] = row['last_name_or_entity_name']
    end
  end

  def search_vendor(vendor)
    results = search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean, vendor.middle_name_clean)

    results.each do |result|
      row = result[:row]
      details = 'Flagged on PA DHS Medicheck List as: '
      details += row['providername']
      details += "\n"

      details += "Status: #{row['status']}"
      details += "\n"

      details += "Begin date: #{row['begindate']}"
      details += "\n"

      details += "End date: #{row['enddate'] || 'not specified'}"
      details += "\n"

      details += "List date: #{row['listdate']}"
      details += "\n"

      if row['license_number'].present?
        details += "License number: #{row['licensenumber']}"
        details += "\n"
      end

      if row['idn_npi'].present?
        details += "NPI number: #{row['idn_npi']}"
        details += "\n"
      end

      result[:details] = details
    end

    results
  end

  def search(last_name_clean, first_name_clean, middle_name_clean)
    # I think nam_last_provr, nam_first_provr, and nam_middle_provr are good for searching employees
    # and nam_busns_mp for vendors

    results = if first_name_clean.present?
                rows = db.execute(
                  'select * from entries where nam_first_provr_clean like ? and nam_last_provr_clean like ?', [first_name_clean + '%',
                                                                                                               last_name_clean + '%']
                )
                rows.select do |row|
                  ApplicationRecord.do_names_match?(last_name_clean, row['nam_last_provr_clean']) &&
                    ApplicationRecord.do_names_match?(first_name_clean, row['nam_first_provr_clean'])
                end
              else
                entity_name_clean = last_name_clean
                rows = db.execute('select * from entries where nam_busns_mp_clean like ?', [entity_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(entity_name_clean, row['nam_busns_mp_clean'])
                end
              end

    results = results.uniq.select do |result|
      if result['nam_middle_provr_clean'].present? && middle_name_clean.present?
        result_middle = Employee.sanitize_name(result['nam_middle_provr_clean'])
        if result_middle.length == 1 || middle_name_clean.length == 1
          # when middle name specified on both, permit when middle initial matches
          result_middle[0] == middle_name_clean[0]
        else
          # ... unless both were fully specified middle names... then remove spaces and check them against each other for a potential match
          result_middle.gsub(/\s+/, '') == middle_name_clean.gsub(/\s+/, '')
        end
      else
        true # when middle name not specified on both, permit any middle name
      end
    end

    results.map do |result|
      {
        row: result,
        dob: :not_checked,
        ssn: :not_checked
      }
    end
  end
end
