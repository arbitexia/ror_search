require 'csv'

module UkgLoader
  extend self

  def xml_paths
    development_ukg_paths = [
      Rails.root.join('ukg_entries.xml'), 
      Rails.root.join('ukg_entries_2.xml')
    ]
    production_ukg_paths = [
      '/home/ubuntu/ukg_entries.xml', 
      '/home/ubuntu/ukg_entries_2.xml'
    ]

    if Rails.env.development?
      development_ukg_paths
    else
      production_ukg_paths
    end
  end

  def read_xml
    results = []
    xml_paths.each do |xml_path|
      next unless File.exist?(xml_path)

      doc = Nokogiri::XML(File.open(xml_path))
      # get machine readable column names
      cols = doc.css('metadata > item').map do |item|
               item['name']
             end.map { |name_human| ApplicationRecord.sanitize_name(name_human).gsub(' ', '_') }
  
      entries = doc.css('data > row')
      entries.each do |entry|
        values = entry.css('value').map { |value| value.text.strip }
        results << Hash[cols.zip(values)].symbolize_keys
      end
    end
    results
  end


  def client_select_options
    entries = read_xml
    options = entries.map { |entry| [entry[:company], entry[:company_code]] }.uniq
    options.sort_by! { |option| option[0] }
    options.insert(0, ['', nil])
    options
  end

  def employees_for_client(ukg_company_code)
    entries = read_xml
    entries.select { |entry| entry[:company_code] == ukg_company_code }
  end

  def sync_employees(client)
    raise "no UKG id on client #{client}" unless client.ukg_id.present?

    client.update(external_sync_progress: 0, external_sync_error: nil)

    ukg_employees = employees_for_client(client.ukg_id)

    i = 0
    ukg_employees.each do |ukg_employee|
      i += 1
      client.update(external_sync_progress: i.to_f / ukg_employees.count.to_f)

      matching_client_employee = client.employees.select do |e|
        e.ukg_id.to_s == ukg_employee[:employee_number].to_s
      end.first

      attributes = {
        ssn: ukg_employee[:ssn_unformatted],
        ukg_id: ukg_employee[:employee_number],
        first_name: ukg_employee[:first_name],
        middle_name: ukg_employee[:middle_name],
        last_name: ukg_employee[:last_name]
      }

      if matching_client_employee.present?
        matching_client_employee.update(attributes)
        verb = 'updated'
      else
        matching_client_employee = client.employees.create!(attributes)
        verb = 'imported'
      end

      puts "#{verb} employee record (UKG ##{matching_client_employee.ukg_id} / CSC ##{matching_client_employee.id}: #{matching_client_employee.full_name})"
    end

    employees_to_delete = # that are not in the latest CM list
      client.employees
            .select { |e| e.ukg_id.present? } # cm employees only
            .select do |e|
        ukg_employees.select do |ukg_employee|
          ukg_employee[:employee_number].to_s == e.ukg_id.to_s
        end.empty?
      end
    employees_to_delete.each(&:destroy!)

    puts "deleted #{employees_to_delete.count} employees"

    puts "#{ukg_employees.count} employees processed from UKG"

    client.update(last_external_sync_at: DateTime.now, external_sync_progress: nil, external_sync_error: nil)
  rescue StandardError => e
    client.update(external_sync_progress: nil, external_sync_error: e.to_s)
    raise e
  end
end
