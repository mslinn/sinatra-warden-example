require 'bcrypt'
require 'data_mapper'
require 'dm-sqlite-adapter'

# See https://code.tutsplus.com/tutorials/ruby-for-newbies-working-with-datamapper--net-19622
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")

# User model
class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, key: true
  property :username, String, length: 128
  property :password, BCryptHash

  def authenticate(attempted_password)
    # `password` is an instance of `BCrypt`, which defines `==` for comparing a
    # plain text string to an encrypted string.
    # See https://github.com/codahale/bcrypt-ruby/blob/master/lib/bcrypt/password.rb#L64-L67
    password == attempted_password
  end
end

# Tell DataMapper the models have been defined
DataMapper.finalize

# Update the database to match the properties of User.
DataMapper.auto_upgrade!

# Create a test User
if User.count.zero?
  @user = User.create(username: 'admin')
  @user.password = 'admin'
  @user.save
end
