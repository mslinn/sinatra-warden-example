DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")

# Need comment
class User
  include DataMapper::Resource

  property :id, Serial, key: true
  property :username, String, length: 128

  property :password, BCryptHash

  def authenticate(attempted_password)
    # The BCrypt class, which `password` is an instance of, has `==` defined to compare a
    # test plain text string to the encrypted string and converts `attempted_password` to a BCrypt
    # for the comparison.
    # See https://github.com/codahale/bcrypt-ruby/blob/master/lib/bcrypt/password.rb#L64-L67
    password == attempted_password
  end
end

# Tell DataMapper the models are done being defined
DataMapper.finalize

# Update the database to match the properties of User.
DataMapper.auto_upgrade!

# Create a test User
if User.count.zero?
  @user = User.create(username: 'admin')
  @user.password = 'admin'
  @user.save
end