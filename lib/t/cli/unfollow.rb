require 'retryable'
require 't/core_ext/enumerable'
require 't/core_ext/string'
require 't/collectable'
require 't/rcfile'
require 'thor'
require 'twitter'

module T
  class CLI
    class Unfollow < Thor
      include T::Collectable

      DEFAULT_HOST = 'api.twitter.com'
      DEFAULT_PROTOCOL = 'https'

      check_unknown_options!

      def initialize(*)
        super
        @rcfile = RCFile.instance
      end

      desc "listed LIST_NAME", "Unfollow all members of a list."
      def listed(list_name)
        list_member_collection = collect_with_cursor do |cursor|
          client.list_members(list_name, :cursor => cursor, :include_entities => false, :skip_status => true)
        end
        number = list_member_collection.length
        return say "@#{@rcfile.default_profile[0]} is already not following any list members." if number.zero?
        return unless yes? "Are you sure you want to unfollow #{number} #{number == 1 ? 'user' : 'users'}?"
        list_member_collection.threaded_map do |list_member|
          retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
            client.unfollow(list_member.id, :include_entities => false)
          end
        end
        say "@#{@rcfile.default_profile[0]} is no longer following #{number} #{number == 1 ? 'user' : 'users'}."
        say
        say "Run `#{$0} follow all listed #{list_name}` to follow again."
      end

      desc "followers", "Unfollow all followers."
      def followers
        follower_ids = collect_with_cursor do |cursor|
          client.follower_ids(:cursor => cursor)
        end
        friend_ids = collect_with_cursor do |cursor|
          friends = client.friend_ids(:cursor => cursor)
        end
        follow_ids = (follower_ids - friend_ids)
        number = follow_ids.length
        return say "@#{@rcfile.default_profile[0]} is already not following any followers." if number.zero?
        return unless yes? "Are you sure you want to unfollow #{number} #{number == 1 ? 'user' : 'users'}?"
        screen_names = follow_ids.threaded_map do |follow_id|
          retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
            client.unfollow(follow_id, :include_entities => false)
          end
        end
        say "@#{@rcfile.default_profile[0]} is no longer following #{number} #{number == 1 ? 'user' : 'users'}."
        say
        say "Run `#{$0} follow all followers` to stop."
      end

      desc "friends", "Unfollow all friends."
      def friends
        friend_ids = collect_with_cursor do |cursor|
          client.friend_ids(:cursor => cursor)
        end
        number = friend_ids.length
        return say "@#{@rcfile.default_profile[0]} is already not following anyone." if number.zero?
        return unless yes? "Are you sure you want to unfollow #{number} #{number == 1 ? 'user' : 'users'}?"
        screen_names = friend_ids.threaded_map do |friend_id|
          retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
            user = client.unfollow(friend_id, :include_entities => false)
            user.screen_name
          end
        end
        say "@#{@rcfile.default_profile[0]} is no longer following #{number} #{number == 1 ? 'user' : 'users'}."
        say
        say "Run `#{$0} follow users #{screen_names.join(' ')}` to follow again."
      end
      map %w(everyone everybody) => :friends

      desc "nonfollowers", "Unfollow all non-followers."
      def nonfollowers
        friend_ids = collect_with_cursor do |cursor|
          client.friend_ids(:cursor => cursor)
        end
        follower_ids = collect_with_cursor do |cursor|
          client.follower_ids(:cursor => cursor)
        end
        unfollow_ids = (friend_ids - follower_ids)
        number = unfollow_ids.length
        return say "@#{@rcfile.default_profile[0]} is already not following any non-followers." if number.zero?
        return unless yes? "Are you sure you want to unfollow #{number} #{number == 1 ? 'user' : 'users'}?"
        screen_names = unfollow_ids.threaded_map do |unfollow_id|
          retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
            user = client.unfollow(unfollow_id, :include_entities => false)
            user.screen_name
          end
        end
        say "@#{@rcfile.default_profile[0]} is no longer following #{number} #{number == 1 ? 'user' : 'users'}."
        say
        say "Run `#{$0} follow users #{screen_names.join(' ')}` to follow again."
      end

      desc "users SCREEN_NAME [SCREEN_NAME...]", "Allows you to stop following users."
      def users(screen_name, *screen_names)
        screen_names.unshift(screen_name)
        screen_names.threaded_map do |screen_name|
          retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
            client.unfollow(screen_name, :include_entities => false)
          end
        end
        number = screen_names.length
        say "@#{@rcfile.default_profile[0]} is no longer following #{number} #{number == 1 ? 'user' : 'users'}."
        say
        say "Run `#{$0} follow users #{screen_names.join(' ')}` to follow again."
      end

    private

      def base_url
        "#{protocol}://#{host}"
      end

      def client
        return @client if @client
        @rcfile.path = parent_options['profile'] if parent_options['profile']
        @client = Twitter::Client.new(
          :endpoint => base_url,
          :consumer_key => @rcfile.default_consumer_key,
          :consumer_secret => @rcfile.default_consumer_secret,
          :oauth_token => @rcfile.default_token,
          :oauth_token_secret  => @rcfile.default_secret
        )
      end

      def host
        parent_options['host'] || DEFAULT_HOST
      end

      def protocol
        parent_options['no_ssl'] ? 'http' : DEFAULT_PROTOCOL
      end

    end
  end
end
