# == Schema Information
#
# Table name: notes
#
#  id         :bigint           not null, primary key
#  client_id  :bigint
#  user_id    :bigint
#  text       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Note < ApplicationRecord
  belongs_to :client
  belongs_to :user
end
