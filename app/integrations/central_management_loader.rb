require 'csv'

module CentralManagementLoader
  extend self

  def csv_path
    if Rails.env.development?
      Rails.root.join('SanctionSearchEmployees.csv')
    else
      '/home/ubuntu/SanctionSearchEmployees.csv'
      # chmod 600 /home/ubuntu/sanction-search/current/SanctionSearch.pem && scp -o StrictHostKeyChecking=no -i /home/ubuntu/sanction-search/current/SanctionSearch.pem /home/test/writable/SanctionSearchEmployees.csv ubuntu@18.216.4.52:~/SanctionSearchEmployees.csv
    end
  end

  def read_csv
    array_of_arrays = CSV.read(csv_path)
    n = 0
    entries = array_of_arrays.map do |line|
      next nil if line.empty?

      n += 1
      cm_client_id, cm_client_name, cm_employee_id, first, middle, last, ssn_hyphenated, dob_slashed = line

      dob = if dob_slashed.present?
              dob_month, dob_day, dob_year = dob_slashed.split('/').map(&:to_i)
              Date.new(dob_year, dob_month, dob_day)
            end

      ssn = (ssn_hyphenated.gsub('-', '') if ssn_hyphenated.present?)

      raise "invalid ssn on line #{n}: #{ssn_hyphenated}" unless ssn.nil? || ssn.length == 9

      {
        client_id: cm_client_id,
        client_name: cm_client_name,
        id: cm_employee_id,
        first_name: first,
        middle_name: middle,
        last_name: last,
        ssn: ssn,
        dob: dob
      }
    end

    entries.compact
  end

  def client_select_options
    entries = read_csv
    options = entries.map { |entry| [entry[:client_name], entry[:client_id]] }.uniq
    options.sort_by! { |option| option[0] }
    options.insert(0, ['', nil])
    options
  end

  def employees_for_client(cm_client_id)
    entries = read_csv
    entries.select { |entry| entry[:client_id] == cm_client_id }
  end

  def sync_employees(client)
    raise "no central management id on client #{client}" unless client.central_management_id.present?

    client.update(external_sync_progress: 0, external_sync_error: nil)

    cm_employees = employees_for_client(client.central_management_id)

    i = 0
    cm_employees.each do |cm_employee|
      i += 1
      client.update(external_sync_progress: i.to_f / cm_employees.count.to_f)

      matching_client_employee = client.employees.select do |e|
        e.central_management_id.to_s == cm_employee[:id].to_s
      end.first

      attributes = {
        ssn: cm_employee[:ssn],
        dob: cm_employee[:dob],
        central_management_id: cm_employee[:id],
        first_name: cm_employee[:first_name],
        middle_name: cm_employee[:middle_name],
        last_name: cm_employee[:last_name]
      }

      if matching_client_employee.present?
        matching_client_employee.update(attributes)
        verb = 'updated'
      else
        matching_client_employee = client.employees.create!(attributes)
        verb = 'imported'
      end

      puts "#{verb} employee record (CM ##{matching_client_employee.central_management_id} / CSC ##{matching_client_employee.id}: #{matching_client_employee.full_name})"
    end

    employees_to_delete = # that are not in the latest CM list
      client.employees
            .select { |e| e.central_management_id.present? } # cm employees only
            .select do |e|
        cm_employees.select do |cm_employee|
          cm_employee[:id].to_s == e.central_management_id.to_s
        end.empty?
      end
    employees_to_delete.each(&:destroy!)

    puts "deleted #{employees_to_delete.count} employees"

    puts "#{cm_employees.count} employees processed from Central Management"

    client.update(last_external_sync_at: DateTime.now, external_sync_progress: nil, external_sync_error: nil)
  rescue StandardError => e
    client.update(external_sync_progress: nil, external_sync_error: e.to_s)
    raise e
  end
end
