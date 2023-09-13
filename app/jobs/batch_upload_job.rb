require 'csv'

class BatchUploadJob < ApplicationJob
  queue_as `hostname`.strip # since this job needs to read a csv file from the local machine, queue it as such

  def perform(batch_upload)
    model = batch_upload.record_type == 'employee' ? Employee : Vendor
    client = batch_upload.client

    csv_contents = File.read(batch_upload.filename)

    errors = []
    reading_header = true
    records = []
    line = 0
    rows = CSV.parse(csv_contents)

    if client.would_exceed_record_count?(rows.count)
      batch_upload.update(progress: 0,
                          error: 'Adding this batch would exceed your maximum count of employees and vendors. Please remove some records before you upload this batch, or contact us to purchase a higher tier of service.')
      return
    end

    rows.each do |row|
      line += 1

      if reading_header
        reading_header = false
        next
      end

      if client.reached_record_count?
        errors << 'You have exceeded your maximum count of employees and vendors. Please remove some records before you can add a new one, or contact us to purchase a higher tier of service.'
        break
      end

      if model == Vendor
        record = client.vendors.new(name: row[0], last_name: row[1], first_name: row[2], middle_name: row[3],
                                    ein: row[4]&.gsub('-', ''), npi: row[5])
      else
        record = client.employees.new(first_name: row[0], middle_name: row[1], last_name: row[2], ssn: row[4])

        begin
          record.dob = Date.strptime(row[3], '%m/%d/%Y') if row[3].present?
        rescue StandardError
          @errors << "Entry on line #{line} (#{row.join('/')}) had a date of birth that was not formatted correctly."
          next
        end
      end

      record.batch_upload = batch_upload

      if record.save
        records << record
      else
        pp record.errors
        errors << "Entry on line #{line} (#{row.join('/')}) was not formatted correctly."
      end

      batch_upload.update(progress: (line - 1).to_f / rows.count.to_f)
    end

    if errors.present?
      batch_upload.update(progress: 1.0, error: errors.join("\n"), imported_record_count: records.count)
    else
      batch_upload.update(progress: 1.0, error: nil, imported_record_count: records.count)

      if batch_upload.run_initial_report
        word = model == Vendor ? 'vendors' : 'employees'
        report = client.reports.create(source: "Initial report for #{records.count} new #{word}")

        if model == Vendor
          report.vendor_mask = records.map(&:id)
        else
          report.employee_mask = records.map(&:id)
        end

        report.save

        job = ReportGeneratorJob.perform_later(report)
        report.update(job_id: job.job_id)
      end
    end
  rescue StandardError => e
    error = ['Unhandled error in main job:', e.to_s, $@].join("\n")
    batch_upload.update(progress: nil, error: error)
  ensure
    FileUtils.rm(batch_upload.filename)
  end
end
