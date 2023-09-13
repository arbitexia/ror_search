require 'csv'

module SAMSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'SAM'
  end

  def db_refresh_url
    dir = Rails.root.join('data', 'sam')
    dir.join(Dir.entries(dir).find { |entry| entry.chars.uniq != ['.'] }).to_s
  end

  def download_latest_csv
    zip_filename = "SAM_Exclusions_Public_Extract_V2_#{Date.today.year - 2000}"
    zip_filename += "#{([Date.today.yday-2,1].max).to_s.rjust(3,'0')}.ZIP"
    zip_url = "https://sam.gov/api/prod/fileextractservices/v1/api/download/Exclusions/Public%20V2/#{zip_filename}?privacy=Public"

    dir = Rails.root.join('data', 'sam')
    FileUtils.rmtree(dir)
    FileUtils.makedirs(dir)
    zip = Rails.root.join('data', 'sam-latest.zip')

    open(zip_url) do |url_file|
      File.binwrite(zip, url_file.read)
    end

    Archive::Zip.extract(File.new(zip), dir)
  end

  def search_employee(employee)
    results = search(employee.last_name_clean, employee.first_name_clean, employee.middle_name_clean, employee.ssn, nil)

    add_details_to_results(results, was_employee_search: true)
    results.reject { |result| result[:ssn] == :no_match }
  end

  def search_vendor(vendor)
    results = search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean, vendor.middle_name_clean,
                     vendor.ein, vendor.npi)

    add_details_to_results(results, was_employee_search: false)
    results.reject { |result| result[:ssn] == :no_match }
  end

  def add_details_to_results(results, was_employee_search: false)
    results.each do |result|
      row = result[:row]

      master_result = results.find do |r|
        r[:row]['sam_number'].present? && r[:row]['sam_number'] == result[:row]['sam_number']
      end || result

      details = 'Flagged on SAM as: '
      details += if row['last'].present? && row['first'].present?
                   "#{row['last']}, #{row['first']} #{row['middle']}"
                 else
                   row['name']
                 end

      details += "\n"

      if was_employee_search
        details += 'Date of Birth was not checked'
        details += "\n"
      end

      if result[:npi] == :match
        details += 'NPI was checked and matched'
        details += "\n"
      end

      ssn_word = was_employee_search ? 'SSN' : 'EIN'
      if result[:ssn] == :not_checked
        details += "#{ssn_word} was not checked"
        details += "\n"
      elsif result[:ssn] == :no_match
        details += "Note: #{ssn_word} was checked and did not match #{ssn_word} on record"
        details += "\n"
      end

      exclusion = '- '

      if row['exclusion_type'].present?
        exclusion += row['exclusion_type']
        exclusion += " (CT code: #{row['ct_code']})" if row['ct_code'].present?
        exclusion += ': '
      end

      exclusion += row['exclusion_program'] + '. ' if row['exclusion_program'].present?

      exclusion += "Excluded by #{row['excluding_agency']}. " if row['excluding_agency'].present?

      if row['active_date'].present? && row['termination_date'].present?
        exclusion += "From #{row['active_date']}-#{row['termination_date']}"
      end

      if row['additional_comments'].present?
        comments = row['additional_comments'].strip.gsub("\n", "\n  ")
        exclusion += "\n  Comments: #{comments}"
      end

      master_result[:details] ||= details
      master_result[:details] += exclusion
      master_result[:details] += "\n"

      result[:first] = row['first']
      result[:last] = row['last']
      result[:middle] = row['middle']
    end
  end

  def search(last_name_clean, first_name_clean, middle_name_clean, ssn_or_ein, npi)
    results = if npi.present?
                rows = db.execute('select * from entries where npi = ?', npi)
                rows
              elsif first_name_clean.present?
                rows = db.execute('select * from entries where first_clean like ? and last_clean like ?',
                                  [first_name_clean + '%', last_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(last_name_clean, row['last_clean']) &&
                    ApplicationRecord.do_names_match?(first_name_clean, row['first_clean'])
                end
              elsif last_name_clean.present?
                entity_name_clean = last_name_clean
                rows = db.execute('select * from entries where name_clean like ?', [entity_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(entity_name_clean, row['name_clean'])
                end
              end

    results = results.uniq.select do |result|
      if result['middle'].present? && middle_name_clean.present?
        result_middle = Employee.sanitize_name(result['middle'])
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
    end.map do |result|
      {
        row: result
      }
    end

    results.each do |result|
      if npi.present?
        result[:npi] = result[:row]['npi'] == npi ? :match : :no_match
      end
    end

    # we filter out no-match NPIs
    results = results.reject { |result| result[:npi] == :no_match }

    if ssn_or_ein.present?
      run_ssn_match(results, ssn_or_ein)
    else
      results.each do |result|
        result[:ssn] = :not_checked
      end
    end

    results
  end

  # processes a result set to determine whether any matching SSN matches our requested SSN.
  # this involves hitting the SAM API with separate requests.
  def run_ssn_match(results, ssn)
    unless ssn.to_s.length == 9
      warn "ssn must be 9 digits: was #{ssn}"
      return
    end
    results.each do |result|
      run_single_ssn_match(result, ssn)
    end
  end

  def run_single_ssn_match(result, ssn)
    row = result[:row]
    first_name = row['first_name'] || ''
    last_name = row['last_name'] || row['name'] || ''
    middle_name = row['middle_name'] || ''

    first_name = first_name.strip
    last_name = last_name.strip
    middle_name = middle_name.strip

    begin
      result[:ssn] = beta_ssn_matches?(first_name, middle_name, last_name, ssn) ? :match : :no_match
    rescue StandardError => e
      warn e
      result[:ssn] = :not_checked
    end
  end

  def beta_ssn_matches?(first_name, middle_name, last_name, ssn)
    timestamp = (Time.now.to_f * 1000).to_i
    params = {
      api_key: 'null',
      random: timestamp,
      index: 'ex',
      page: 0,
      sort: '-relevance',
      size: 25,
      mfe: true,
      mode: 'search',
      is_active: true,
      domain: 'search_entity',
      excluded_party_ssn: [{ ssn: ssn, lastName: last_name, firstName: first_name, middleName: middle_name }].to_json
    }
    url = "https://sam.gov/api/prod/sgs/v1/search/?#{params.to_query}"

    resp = RestClient::Request.execute(method: :get,
                                      url: url,
                                      timeout: 120)
    json = JSON.parse(resp.body)

    json['page']['totalElements'] > 0
  end
end
