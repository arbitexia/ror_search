module LayoutsHelper
  def parent_layout(layout)
    @view_flow.set(:layout, output_buffer)
    output = render(file: "layouts/#{layout}")
    self.output_buffer = ActionView::OutputBuffer.new(output)
  end

  def client_header(title, client, referrer)
    if client.present?
      header = content_tag('header', class: :'portal-header') { client.legal_business_name }

      header = if referrer.present? && referrer.include?('/clients/') && !referrer.include?('/reports')
                 header.concat(link_to("Back to #{client.client_type.capitalize} Home", client_path(client),
                                       class: 'back-link'))
               else
                 header.concat(link_to('Back', referrer, class: 'back-link'))
               end

      header = header.concat(content_tag('header', class: :'section-header') { title })
    else
      content_tag('header', class: :'portal-header') { title }
    end
  end
end
