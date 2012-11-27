require_relative 'dbauth'

class AuthenticationManager

  def self.prepare_sources(sources)
    sources.map { |source|
      model = Kernel.const_get(source[:model].intern)

      model.new(source)
    }
  end

  def self.authentication_sources
    [DBAuth] + prepare_sources(AppConfig[:authentication_sources])
  end


  # Attempt to authenticate `user' with the provided `password'.
  # Return a User object if successful, nil otherwise
  def self.authenticate(username, password)
    authentication_sources.each do |source|
      begin
        user = source.authenticate(username, password,
                                   proc { |name|
                                     user = User.find(:username => username)

                                     if user
                                       # Update them from the authentication source
                                       user.update(:name => name,
                                                   :source => source.name)

                                       user
                                     else
                                       # Create a new record for this user
                                       User.create(:name => name,
                                                   :source => source.name,
                                                   :username => username)
                                     end
                                   })

        return user if user
      rescue
        Log.error("Error communicating with authentication source #{source.inspect}: #{$!}")
        Log.exception($!)
        next
      end
    end

    nil
  end


  ArchivesSpaceService.loaded_hook do
    # Fire this at load time to sanity check our source definitions
    self.authentication_sources
  end
end
