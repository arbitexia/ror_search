# == Schema Information
#
# Table name: reports
#
#  id               :bigint           not null, primary key
#  job_id           :string
#  client_id        :bigint
#  filename         :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  progress         :float
#  error            :string
#  status           :string
#  data             :json
#  source           :string
#  employee_mask    :integer          is an Array
#  vendor_mask      :integer          is an Array
#  parent_report_id :bigint
#  month            :integer
#  year             :integer
#
class Report < ApplicationRecord
  belongs_to :client
  belongs_to :parent_report, class_name: 'Report', optional: true
  has_many :child_reports, class_name: 'Report', foreign_key: :parent_report_id
  has_one :failed_report, dependent: :destroy

  scope :desc, -> { order(created_at: :desc) }
  scope :failed, -> { where.not(error: nil) }
  scope :successful, -> { where(error: nil) }

  MONTHLY_REPORT_SOURCE = 'Automatic Monthly Report'

  # def mark_failure(error)
  #   return failed_report if failed_report.present?

  #   update(progress: nil, error: error)
  #   create_failed_report(id)
  # end

  # def unmark_failure
  #   return if failed_report.blank?

  #   failed_report.destroy
  # end

  def num_flagged_records
    return 0 if data.nil?

    (data['employees'] + data['vendors']).select { |record| record['results'].present? }.count
  end

  def run_now!
    ReportGeneratorJob.new.perform(self)
  end

  def complete?
    !data.nil? && progress.nil?
  end

  def summary
    return {
      employees: {
        positive: nil,
        potential: nil,
        expired: nil,
        excluded: nil,
        cleared: nil
      },
      vendors: {
        positive: nil,
        potential: nil,
        excluded: nil,
        expired: nil,
        cleared: nil
      }
    } unless data.present?

    @positive_employees ||= data['employees'].select { |record| self.class.positive_match?(record) }.count
    @positive_vendors ||= data['vendors'].select { |record| self.class.positive_match?(record) }.count
    @potential_employees ||= data['employees'].select do |record|
      self.class.potential_match?(record) && !self.class.positive_match?(record)
    end.count
    @potential_vendors ||= data['vendors'].select do |record|
      self.class.potential_match?(record) && !self.class.positive_match?(record)
    end.count
    @expired_employees ||= data['employees'].select { |record| self.class.expiry?(record) }.count
    @excluded_employees ||= data['employees'].select { |record| self.class.is_employee_excluded?(record) }.count
    @excluded_vendors ||= data['vendors'].select { |record| self.class.is_vendor_excluded?(record) }.count
    @expired_vendors ||= data['vendors'].select { |record| self.class.expiry?(record) }.count

    @summary ||= {
      employees: {
        positive: @positive_employees,
        potential: @potential_employees,
        expired: @expired_employees,
        excluded: @excluded_employees,
        cleared: data['employees'].count - @positive_employees - @potential_employees - @expired_employees
      },
      vendors: {
        positive: @positive_vendors,
        potential: @potential_vendors,
        excluded: @excluded_vendors,
        expired: @expired_vendors,
        cleared: data['vendors'].count - @positive_vendors - @potential_vendors
      }
    }
  end

  def num_positive_matches
    @num_positive_matches ||= summary[:employees][:positive] + summary[:vendors][:positive]
  end

  def num_potential_matches
    @num_potential_matches ||= summary[:employees][:potential] + summary[:vendors][:potential]
  end

  def num_excluded_matches
    @num_excluded_matches ||= summary[:employees][:excluded] + summary[:vendors][:excluded]
  end

  def num_expired_matches
    @num_expired_matches ||= summary[:employees][:expired] + summary[:vendors][:expired]
  end

  def num_total_records
    return 0 if data.nil?

    @num_total_records ||= (data['employees'] + data['vendors']).count
  end

  class << self
    def positive_match?(record)
      return false if is_excluded?(record)

      if record['employee'].present?
        record['results'].any? do |result|
          positive_employee_result?(result, record)
        end
      else
        record['results'].any? do |result|
          positive_vendor_result?(result, record)
        end
      end
    end

    def positive_vendor_result?(result, _record)
      return false if result['type'] == 'expiry' # exclude expirations
      return true if result['force_type'] == 'positive'

      result['ssn'] == 'match' || result['npi'] == 'match'
    end

    def positive_employee_result?(result, record)
      return false if result['type'] == 'expiry' # exclude expirations
      return true if result['force_type'] == 'positive'

      # return false unless Employee.exists?(record['employee']['id'])

      # employee = Employee.find(record['employee']['id'])
      # full_name = employee.full_name

      first_name = record['employee']['first_name']
      last_name = record['employee']['last_name']
      middle_name = record['employee']['middle_name']
      full_name = "#{first_name} #{middle_name}".rstrip + " #{last_name}"

      # if SSN matches, it is a positive match.
      if result['ssn'] == 'match'
        true
      elsif result['ssn'] == 'not_checked' && result['last'].present?
        # if SSN was not checked and DOB and full name match, then it is a positive match.
        result_name = "#{result['first']} #{result['middle']}".rstrip + " #{result['last']}"
        result['dob'] == 'match' && full_name_match?(result_name, full_name)
      else
        # if SSN did not match it is automatically not positive, even if name/dob match. if either name/dob doesn't match, it is not positive.
        false
      end
    end

    def full_name_match?(result_name, our_name)
      result_name.mb_chars.downcase.to_s == our_name.mb_chars.downcase.to_s
    end

    def get_blocked_searchers(record)
      return record['blocked_searchers'] if record['blocked_searchers'].present?

      # legacy fallback
      if record['employee'].present?
        record['employee']['blocked_searchers'] || []
      elsif record['vendor'].present?
        record['vendor']['blocked_searchers'] || []
      else
        []
      end
    end

    def potential_match?(record)
      return false if is_excluded?(record)
      return true if record['force_type'] == 'potential'

      # has matches, and at least one of the matches is not an expiry, i.e. is a violation
      record['results'].present? && record['results'].any? { |result| result['type'] != 'expiry' }
    end

    def expiry?(record)
      return false if is_excluded?(record)

      # has matches, and all of the matches are an expiry
      record['results'].present? && record['results'].all? { |result| result['type'] == 'expiry' }
    end

    def is_excluded?(record)
      return false if record['results'].empty?

      blocked_searchers = get_blocked_searchers(record)

      record['results'].all? do |result|
        blocked_searchers.include?(result['searcher'])
      end
    end

    def is_employee_excluded?(record)
      is_excluded?(record)
    end

    def is_vendor_excluded?(record)
      is_excluded?(record)
    end
  end
end
