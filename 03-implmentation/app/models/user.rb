class User < ApplicationRecord
  has_secure_password

  ROLES = %w[admin operator viewer].freeze

  before_save { self.email = email.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end
end
