class ApplicationMailer < ActionMailer::Base
  default from: 'noreply@sanctionsearch.net', to: 'info@pmcresources.com'
  layout 'mailer'
end
