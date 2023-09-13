require 'csv'

module DHSARSearcher
  include DatabaseSearcher
  extend self

  def db_name
    'DHSAR'
  end

  def db_refresh_url
    'https://dhs.arkansas.gov/dhs/portal/Exclusions/PublicSearch/Download'
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

      details = 'Flagged on Arkansas DHS Excluded Provider List as: '

      if was_employee_search
        details += row['provider_name']

        details += "\n"

        if row['facility_name'].present?
          details += "Flagged at facility:\n"
          details += row['facility_name']
          details += "\n"
        end

        details += 'Date of Birth was not checked'
        details += "\n"
        details += 'SSN was not checked'
        details += "\n"
      else
        details += row['facility_name']

        details += "\n"

        if row['provider_name'].present?
          details += "Provider within facility was also flagged:\n"
          details += row['provider_name']
          details += "\n"
        end
      end

      location = ''
      location += row['city'] if row['city'].present?
      if row['state'].present?
        location += ', ' if row['city'].present?

        location += row['state']
      end
      if row['zip'].present?
        location += ' '
        location += row['zip']
      end

      location = location.strip

      details += "Location: #{location}\n" if location.present?

      details += "Division: #{row['division']}\n" if row['division'].present?

      details += "\n"

      result[:details] ||= details

      result[:first] = nil
      result[:last] = nil
      result[:middle] = nil
    end
  end

  def search(last_name_clean, first_name_clean = nil, middle_name_clean = nil)
    search_string = "#{last_name_clean} #{first_name_clean}%"

    results = if first_name_clean.present?
                rows = db.execute('select * from entries where provider_name_clean like ?', [search_string])

                rows.select do |row|
                  external_last_name = row['provider_name'].split(',')[0]
                  external_first_and_middle_name = row['provider_name'].split(',')[1]
                  ApplicationRecord.do_names_match?(last_name_clean,
                                                    Vendor.sanitize_name(external_last_name)) && ApplicationRecord.do_first_and_middle_names_match?(first_name_clean,
                                                                                                                                                    middle_name_clean, Vendor.sanitize_name(external_first_and_middle_name))
                end
              elsif last_name_clean.present?
                entity_name_clean = last_name_clean
                rows = db.execute('select * from entries where facility_name_clean like ?', [entity_name_clean + '%'])
                rows.select do |row|
                  ApplicationRecord.do_names_match?(entity_name_clean, row['facility_name_clean'])
                end
              end

    results.uniq.map do |result|
      {
        row: result
      }
    end
  end
end
