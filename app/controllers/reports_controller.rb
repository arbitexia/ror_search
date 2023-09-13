class ReportsController < ApplicationController
  layout 'portal'

  before_action :restrict_to_owning_client_or_admin

  def index
    @client = Client.find(params[:client_id])
    @reports = @client.reports.desc.paginate(page: params[:page], per_page: 20)
  end

  def create
    @client = Client.find(params[:client_id])
    @report = @client.reports.create(source: current_user.name)
    @report.update(job_id: ReportGeneratorJob.perform_later(@report).job_id)
    redirect_to action: :index
  end

  def rerun
    @client = Client.find(params[:client_id])
    @report = @client.reports.find(params[:id])
    @report.update(job_id: ReportGeneratorJob.perform_now(@report), error: nil, progress: nil)
    redirect_to action: :index
  end

  def show
    @client = Client.find(params[:client_id])
    @report = @client.reports.find(params[:id])

    # fetch employees referenced in the report, if they have been deleted they'll just be missing from this array
    @employees = Employee.where(id: @report.data['employees'].map { |record| record['employee']['id'] })

    @employees_mask = params[:employees_mask].split(',').map(&:to_i) if params[:employees_mask].present?

    @vendors = Vendor.where(id: @report.data['vendors'].map { |record| record['vendor']['id'] })

    @vendors_mask = params[:vendors_mask].split(',').map(&:to_i) if params[:vendors_mask].present?

    if params[:masked].present?
      # empty arrays are lost in the request, so if we are explicitly masking our results by a selection
      # but missing a mask for either employees or vendors, assume that means we want to hide that entire category
      @employees_mask ||= []
      @vendors_mask ||= []
    end
  end

  def pre_adverse_action_report
    @client = Client.find(params[:client_id])
    @applicant_name = params[:applicant_name]

    # # Initialize DocxReplace with your template
    # doc = DocxReplace::Doc.new("#{Rails.root}/pre_adverse_action_letter.docx", "#{Rails.root}/tmp")
    #
    # # Replace some variables. $var$ convention is used here, but not required.
    # doc.replace("$applicant_name$", applicant_name)
    # doc.replace("$date$", Date.today.to_formatted_s(:long))
    # doc.replace("$client_name$", @client.legal_business_name)
    # doc.replace("$client_address_line1$", @client.mailing_address)
    # doc.replace("$client_city$", @client.mailing_city)
    # doc.replace("$client_state$", @client.mailing_state)
    # doc.replace("$client_zip$", @client.mailing_zip)
    #
    # # Write the document back to a temporary file
    # tmp_file = Tempfile.new('word_tempate' + Time.now.to_f.to_s, "#{Rails.root}/tmp")
    # doc.commit(tmp_file.path)
    #
    # # Respond to the request by sending the temp file
    # send_file tmp_file.path, filename: "Pre-Adverse Action Letter #{applicant_name}.docx", disposition: 'inline'
  end

  def adverse_action_report
    @client = Client.find(params[:client_id])
    @applicant_name = params[:applicant_name]

    # # Initialize DocxReplace with your template
    # doc = DocxReplace::Doc.new("#{Rails.root}/adverse_action_letter.docx", "#{Rails.root}/tmp")
    #
    # # Replace some variables. $var$ convention is used here, but not required.
    # doc.replace("$applicant_name$", applicant_name)
    # doc.replace("$date$", Date.today.to_formatted_s(:long))
    # doc.replace("$client_name$", @client.legal_business_name)
    # doc.replace("$client_address_line1$", @client.mailing_address)
    # doc.replace("$client_city$", @client.mailing_city)
    # doc.replace("$client_state$", @client.mailing_state)
    # doc.replace("$client_zip$", @client.mailing_zip)
    #
    # # Write the document back to a temporary file
    # tmp_file = Tempfile.new('word_tempate' + Time.now.to_f.to_s, "#{Rails.root}/tmp")
    # doc.commit(tmp_file.path)
    #
    # # Respond to the request by sending the temp file
    # send_file tmp_file.path, filename: "Adverse Action Letter #{applicant_name}.docx", disposition: 'inline'
  end

  def fcra_summary
    # send_file "#{Rails.root}/fcra_summary.pdf", filename: "Summary of Rights Under FCRA.pdf", disposition: 'inline'
  end

  protected

  def restrict_to_owning_client_or_admin
    @client = Client.find(params[:client_id])
    render_403 unless user_has_access_to_client?(@client)

    if params[:id].present? && Report.exists?(params[:id]) && !(Report.find(params[:id]).client_id.to_s == params[:client_id])
      render_403
    end
  end
end

# Replace words that are split by XML tags in Microsoft Word
# e.g. replace the tag {{plejefamilie_cpr}} from:
#  {{</w:t></w:r><w:proofErr w:type=\"spellStart\"/><w:r><w:rPr>
#  <w:rFonts w:cstheme=\"minorHAnsi\"/></w:rPr><w:t>
#  plejefamilie_cp</w:t>r</w:t></w:r><w:r w:rsidRPr=\"00996BA1\">
#  <w:rPr><w:rFonts w:cstheme=\"minorHAnsi\"/></w:rPr><w:t>
#  r</w:t></w:r><w:proofErr w:type=\"spellEnd\"/>
#  <w:r w:rsidRPr=\"00996BA1\"><w:rPr><w:rFonts w:cstheme=\"minorHAnsi\"/>
#  </w:rPr><w:t>}}

XML_TAG = /<[^>]+>/

def word_xml_gsub!(word_xml, pattern, replacement)
  regexp = //
  tag_pattern = '' # tag_pattern is the resulting replacement with the XML tags intact
  replacement = replacement.to_s.encode(xml: :text)

  # Generate tag_pattern and regexp
  pattern.to_s.each_char.each_with_index do |char, i|
    rc = Regexp.quote(char)
    regexp = /#{regexp}(?<tag#{i}>(#{XML_TAG})*)#{rc}/
    tag_pattern << '\k<tag' + i.to_s + '>'
    tag_pattern << replacement if i == 0
  end

  tag_pattern.force_encoding('ASCII-8BIT')

  word_xml.gsub!(regexp, tag_pattern)
end

module DocxReplace
  class Doc
    def replace(template, replacement)
      word_xml_gsub!(instance_variable_get(:@document_content), template, replacement)
    end
  end
end
