class User < ApplicationRecord
  include StringNormalizer

  mount_uploader :user_image, ImageUploader

  attr_accessor :remember_token, :reset_token, :activation_token, :confirmation_token

  has_many :todos, dependent: :destroy
  has_many :shortcuts, dependent: :destroy
  has_many :labels, dependent: :destroy

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i.freeze

  before_save :email_downcase
  before_create :create_activation_digest
  before_validation do
    self.username = normalize_as_text(username)
    self.email = normalize_as_email(email)
    self.unconfirmed_email = normalize_as_email(unconfirmed_email)
  end

  validates :username,
            presence: true,
            length: { maximum: 20 }
  validates :email,
            presence: true,
            length: { maximum: 255 },
            format: { with: VALID_EMAIL_REGEX, message: 'の形式を正しく入力してください。' },
            uniqueness: { case_sensitive: false }
  validates :unconfirmed_email,
            presence: true,
            format: { with: VALID_EMAIL_REGEX, message: 'の形式を正しく入力してください。' },
            length: { maximum: 255 },
            uniqueness: { case_sensitive: false },
            allow_nil: true
  validates :password,
            presence: true,
            confirmation: true,
            on: :create
  validates :password_confirmation,
            presence: true,
            on: :create

  has_secure_password

  class << self
    def digest(string)
      cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
      BCrypt::Password.create(string, cost: cost)
    end

    def new_token
      SecureRandom.urlsafe_base64
    end

    def email_used?(user, email)
      existing_user = find_by('email = ?', email)
      existing_user.present? && existing_user != user
    end

    def find_or_create_from_oauth(auth)
      provider = auth[:provider]
      uid = auth[:uid]
      name = auth[:info][:name]
      email = auth[:info][:email]

      if user = User.find_by(email: email)
        if provider == 'twitter' && user.twitter_uid.nil?
          user.update(twitter_uid: uid)
        elsif provider == 'facebook' && user.facebook_uid.nil?
          user.update(facebook_uid: uid)
        elsif provider == 'google_oauth2' && user.google_uid.nil?
          user.update(google_uid: uid)
        end

        unless user.activated?
          user.update(
            activated: true,
            activated_at: Time.zone.now,
            activation_digest: nil
          )
        end
      else
        user = User.find_by(twitter_uid: uid) ||
               User.find_by(facebook_uid: uid) ||
               User.find_by(google_uid: uid)
      end

      unless user
        password = new_token
        user = User.create!(
          username: name,
          email: email,
          password: password,
          password_confirmation: password,
          auto_generated_password: true,
          activated: true,
          activated_at: Time.zone.now,
          twitter_uid: nil,
          facebook_uid: nil,
          google_uid: nil
        )

        if provider == 'twitter'
          user.update(twitter_uid: uid)
        elsif provider == 'facebook'
          user.update(facebook_uid: uid)
        elsif provider == 'google_oauth2'
          user.update(google_uid: uid)
        end
      end
      user
    end
  end

  def activate
    update_columns(activated: true, activated_at: Time.zone.now)
  end

  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?

    BCrypt::Password.new(digest).is_password?(token)
  end

  def forget
    update_attribute(:remember_digest, nil)
  end

  def create_reset_digest
    self.reset_token = User.new_token
    update_attribute(:reset_digest, User.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end

  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  def expired?(attribute)
    published_time = send("#{attribute}_sent_at")
    published_time < 2.hours.ago
  end

  # users_controller.rbの55行目に移動しました

  # def set_unconfirmed_email(email)
  # self.unconfirmed_email = email
  # self.confirmation_token = User.new_token
  # update_attribute(:confirmation_digest, User.digest(confirmation_token))
  # update_attribute(:confirmation_sent_at, Time.zone.now)
  # save
  # UserMailer.email_confirmation(self).deliver_now
  # end

  def update_new_email
    update_columns(email: unconfirmed_email, unconfirmed_email: nil)
  end

  def cancel_oauth(provider)
    if provider == 'twitter' && twitter_uid
      update(twitter_uid: nil)
    elsif provider == 'facebook' && facebook_uid
      update(facebook_uid: nil)
    elsif provider == 'google' && google_uid
      update(google_uid: nil)
    end
  end

  def create_activation_digest
    self.activation_token =  User.new_token
    self.activation_digest = User.digest(activation_token)
  end

  private

  def email_downcase
    email.downcase! if email
    unconfirmed_email.downcase! if unconfirmed_email
  end
end