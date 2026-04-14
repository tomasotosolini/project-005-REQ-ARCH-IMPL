class User < ApplicationRecord
  has_secure_password

  ROLES = %w[guest user admin].freeze

  GRANTS = %i[creator activator monitor editor].freeze

  ROLE_GRANTS = {
    "guest" => %i[monitor],
    "user"  => %i[monitor activator],
    "admin" => %i[creator activator monitor editor]
  }.freeze

  before_save { self.email = email.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: ROLES }

  def has_grant?(grant)
    ROLE_GRANTS.fetch(role, []).include?(grant.to_sym)
  end

  def admin?
    role == "admin"
  end
end
