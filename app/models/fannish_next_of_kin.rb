class FannishNextOfKin < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true
  validates :kin_id, presence: true
  validates :kin_email, presence: true

  def kin_name
    User.find_by_id(kin_id).login
  end
  
  def user_name
    User.find_by_id(user_id).login
  end

end