module DSWSearcher
  extend self

  def search_employee(employee)
    %w[CNA].flat_map do |search_type|
      scraper = DSWScraper.new
      rows = scraper.search_scrape(employee, search_type, employee.id)

      p rows

      # filter out "passed" rows
      if search_type == 'CNA'
        rows = rows.select { |row| row['status'] != 'Certified' }
      elsif search_type == 'DSW'
        rows = rows.select { |row| row['status']&.include?('Finding') }
      end

      # write details about why each row was flagged
      rows.map do |row|
        result = { row: row }

        search_type_human = search_type == 'CNA' ? 'LA CNA' : 'DSW'
        details = "Flagged on #{search_type_human} as: "
        details += row['last_name']
        details += ', '
        details += row['first_name']
        details += "\n"

        if search_type == 'CNA'
          details += 'Status: '
          details += row['status']
          details += "\n"

          details += 'Certification Number: '
          details += row['certification_number']
          details += "\n"

          details += 'Certified From/To: '
          details += row['certified_from_to']
          details += "\n"

          has_expiry = false
          if row['certified_from_to'].present?
            certified_to_string = row['certified_from_to'].split(' - ').last.strip
            certified_to = Date.strptime(certified_to_string, '%m/%d/%Y')
            has_expiry = Date.today > certified_to
          end

          result[:type] = has_expiry ? :expiry : :violation
        elsif search_type == 'DSW'
          details += row['status']
          details += "\n"
          details += 'Registration Number: '
          details += row['registration_number']
          details += "\n"

          result[:type] = :violation
        end

        if employee.ssn.present? && employee.ssn.length == 9
          details += 'Matched by SSN (DOB not checked)'
          details += "\n"

          result[:ssn] = :match
          result[:dob] = :not_checked
        elsif employee.dob.present?
          details += 'Matched by DOB (SSN not checked)'
          details += "\n"

          result[:ssn] = :not_checked
          result[:dob] = :match
        else
          result[:ssn] = :not_checked
          result[:dob] = :not_checked
        end

        if result[:dob] == :not_checked && result[:ssn] == :not_checked
          details += 'Date of Birth was not checked'
          details += "\n"
          details += 'SSN was not checked'
          details += "\n"
        end

        result[:details] = details
        result[:first] = row['first_name']
        result[:last] = row['last_name']

        result
      end
    end
  end

  class DSWScraper < ViewStateScraper
    def base_url
      'https://tlc.dhh.la.gov/'
    end

    # search_type: CNA or DSW
    # both return first_name and last_name parsed from the respective name column in each result
    # CNA additionally returns {certification_number: numeric, certified_from_to: "mm/dd/yyyy - mm/dd/yyyy", original_certification: mm/dd/yyyy, status: Certified|Not Certified|Call CNA Registry, retest_required_by: mm/dd/yyyy (optional)}
    # DSW additionally returns {registration_number: numeric, original_registration: mm/dd/yyyy (optional), status: "Finding mm/dd/yy", retest_required_by: ? (blank?)}
    def search_scrape(employee, search_type, employee_id = 0)
      params = {}
      if employee.ssn.present? && employee.ssn.length == 9
        params.merge!(
          txtFn: '',
          txtMn: '',
          txtLn: '',
          txtDOB: '',
          txtSSNNum: employee.ssn.gsub(/(\d{3})(\d{2})(\d{4})/, '\1-\2-\3') # add dashes to ssn
        )
      else
        params.merge!(
          txtFn: employee.first_name.gsub(/'/, "''"),
          txtMn: '',
          txtLn: employee.last_name.gsub(/'/, "''"),
          txtDOB: employee.dob&.strftime('%m/%d/%Y') || '',
          txtSSNNum: ''
        )
      end
      params.merge!(cboEmployeeType: search_type, btnSearch: 'Search')

      response = do_viewstate_request('https://tlc.dhh.la.gov/frmsearchweb2.aspx', params, false, employee_id)
      body = response.body
      html = Nokogiri::HTML(body)

      # File.write('results.html', body)
      # `open results.html`

      if body.include?('No Data.')
        # no search results
        []
      else
        # scrape the table into a raw row-set (array of hashes with keys corresponding to column headers)
        columns = nil
        rows = []
        html.css('table#dgvList tr').each do |tr|
          if columns.nil?
            columns = tr.css('th').map { |th| th.text.gsub(/\W+/, ' ').strip.gsub(/\s+/, '_').downcase }
            p columns
          else
            values = tr.css('td').map { |td| td.text.strip }
            rows << Hash[columns.zip(values)]
          end
        end

        name_column = if search_type == 'CNA'
                        'name_cna'
                      else
                        'name_dsw'
                      end

        p rows

        rows.select do |row|
          # split names into first/last
          name = row[name_column]

          names = name.split(', ')
          last_name = names[0]
          first_name = names[1...names.count].join(', ') # Adams, Jeff, Jr. => { first: Jeff, Jr.; last: Adams }

          row['first_name'] = first_name
          row['last_name'] = last_name
          row.delete(name_column)

          first_name_clean = ApplicationRecord.sanitize_name(first_name)
          last_name_clean = ApplicationRecord.sanitize_name(last_name)

          # only pass records where names match using our criteria -- CNA/DSW search does a really naive search
          # "Al" matches Alex, Alexander, Alexis, Alejandro etc.
          ApplicationRecord.do_names_match?(employee.last_name_clean, last_name_clean) &&
            ApplicationRecord.do_names_match?(employee.first_name_clean, first_name_clean)
        end
      end
    end
  end
end
