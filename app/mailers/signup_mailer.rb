class SignupMailer < ApplicationMailer
  def signup_email(name, email, phone, company_name, employees)
    @name = name
    @email = email
    @phone = phone
    @company_name = company_name
    @employees = employees
    mail(subject: "Sanction Search: Request for Signup from '#{name}'")
  end

  def report_email(email)
    mail(to: email, subject: 'Sanction Search monthly report available')
  end
end
