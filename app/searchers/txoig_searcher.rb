require 'csv'

module TXOIGSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'TXOIG'
  end

  def db_refresh_url
    Rails.root.join('data', 'txoig.tsv')
  end

  def download_latest_tsv
    tsv_data = TXOIGScraper.new.get_latest_tsv
    f = File.open(db_refresh_url, 'w')
    f.set_encoding(tsv_data.encoding)
    f.write(tsv_data)
  end

  def search_employee(employee)
    results = search(employee.last_name_clean, employee.first_name_clean, employee.middle_name_clean)

    add_details_to_results(results, was_employee_search: true)
    results
  end

  def search_vendor(vendor)
    results = search(vendor.last_name_or_entity_name_clean, vendor.first_name_clean, vendor.middle_name_clean)

    add_details_to_results(results, was_employee_search: false)
    results
  end

  def add_details_to_results(results, was_employee_search: false)
    results.each do |result|
      row = result[:row]

      details = 'Flagged on Texas OIG as: '
      details += if row['lastname'].present? && row['firstname'].present?
                   "#{row['lastname']}, #{row['firstname']} #{row['midinitial']}"
                 else
                   row['companyname']
                 end

      details += "\n"

      if was_employee_search
        details += 'Date of Birth was not checked'
        details += "\n"
        details += 'SSN was not checked'
        details += "\n"
      end

      details += "Occupation: #{row['occupation']}\n" if row['occupation'].present?

      details += "License Number: #{row['licensenumber']}\n" if row['licensenumber'].present?

      details += "NPI: #{row['npi']}\n" if row['npi'].present?

      details += "Started: #{row['startdate']}\n" if row['startdate'].present?

      details += "Reinstated: #{row['reinstateddate']}\n" if row['reinstateddate'].present?

      details += "Comments: #{row['webcomments']}\n" if row['webcomments'].present?

      result[:details] ||= details
      result[:details] += "\n"

      result[:first] = row['firstname']
      result[:last] = row['lastname']
      result[:middle] = row['midinitial']
    end
  end

  def search(last_name_clean, first_name_clean = nil, middle_name_clean = nil)
    results = if first_name_clean.present?
                rows = db.execute('select * from entries where firstname_clean like ? and lastname_clean like ?',
                                  [first_name_clean + '%', last_name_clean + '%'])
                rows.select do |row|
                  firstname = row['firstname_clean'] if row.has_key?('firstname_clean')
                  lastname = row['lastname_clean'] if row.has_key?('lastname_clean')
                  ApplicationRecord.do_names_match?(last_name_clean, lastname) &&
                    ApplicationRecord.do_names_match?(first_name_clean, firstname)
                end
              else
                entity_name_clean = last_name_clean
                rows = db.execute('select * from entries where companyname_clean like ?', [entity_name_clean + '%'])
                rows.select do |row|
                  company_name_clean = row['companyname_clean'] if row.has_key?('companyname_clean')
                  ApplicationRecord.do_names_match?(entity_name_clean, company_name_clean)
                end
              end

    results.uniq.select do |result|
      if result['midinitial_clean'].present? && middle_name_clean.present?
        result_middle = Employee.sanitize_name(result['midinitial_clean'])

        # when middle name specified on both, permit when middle initial matches
        result_middle.chars.first == middle_name_clean.chars.first
      else
        true # when middle name not specified on both, permit any middle name
      end
    end.map do |result|
      {
        row: result
      }
    end
  end

  class TXOIGScraper < ViewStateScraper
    def base_url
      'https://oig.hhsc.state.tx.us/oigportal2/Exclusions/ctl/DOW/mid/384'
    end

    def get_latest_tsv
      # simulates clicking the 'load csv file' button
      response = do_viewstate_request(base_url, {
                                        '__EVENTTARGET' => 'dnn$ctr384$DownloadExclusionsFile$lb_DLoad_ExcFile',
                                        '__EVENTARGUMENT' => '',
                                        '__dnnVariable' => '`{`__scdoff`:`1`,`sf_siteRoot`:`/oigportal2/`,`sf_tabId`:`33`}',
                                        '__VIEWSTATEENCRYPTED' => '',
                                        'dnn_ctr384_DownloadExclusionsFile_radTBMain_Exclusions_radTBMain_Exclusions_ClientState' => ''
                                      }, true)

      data = response.body

      doctype_string = '<!DOCTYPE html>'
      data = data.split(doctype_string).first if data.include?(doctype_string)

      data
    end
  end
end
