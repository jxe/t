require 't/core_ext/string'
require 't/rcfile'
require 'thor'
require 'twitter'

module T
  class CLI
    class Delete < Thor
      DEFAULT_HOST = 'api.twitter.com'
      DEFAULT_PROTOCOL = 'https'

      check_unknown_options!

      def initialize(*)
        super
        @rcfile = RCFile.instance
      end

      desc "block SCREEN_NAME", "Unblock a user."
      def block(screen_name)
        screen_name = screen_name.strip_at
        user = client.unblock(screen_name, :include_entities => false)
        say "@#{@rcfile.default_profile[0]} unblocked @#{user.screen_name}."
        say
        say "Run `#{$0} block #{user.screen_name}` to block."
      end

      desc "dm", "Delete the last Direct Message sent."
      def dm
        direct_message = client.direct_messages_sent(:count => 1, :include_entities => false).first
        if direct_message
          unless parent_options['force']
            return unless yes? "Are you sure you want to permanently delete the direct message to @#{direct_message.recipient.screen_name}: \"#{direct_message.text}\"?"
          end
          direct_message = client.direct_message_destroy(direct_message.id, :include_entities => false)
          say "@#{direct_message.sender.screen_name} deleted the direct message sent to @#{direct_message.recipient.screen_name}: \"#{direct_message.text}\""
        else
          raise Thor::Error, "Direct Message not found"
        end
      end
      map %w(m) => :dm

      desc "favorite", "Deletes the last favorite."
      def favorite
        status = client.favorites(:count => 1, :include_entities => false).first
        if status
          unless parent_options['force']
            return unless yes? "Are you sure you want to delete the favorite of @#{status.user.screen_name}'s latest status: \"#{status.text}\"?"
          end
          client.unfavorite(status.id, :include_entities => false)
          say "@#{@rcfile.default_profile[0]} unfavorited @#{status.user.screen_name}'s latest status: \"#{status.text}\""
          say
          say "Run `#{$0} favorite #{status.user.screen_name}` to favorite."
        else
          raise Thor::Error, "Tweet not found"
        end
      end
      map %w(fave) => :favorite

      desc "list LIST_NAME", "Delete a list."
      def list(list_name)
        unless parent_options['force']
          return unless yes? "Are you sure you want to permanently delete the list \"#{list_name}\"?"
        end
        status = client.list_destroy(list_name)
        say "@#{@rcfile.default_profile[0]} deleted the list \"#{list_name}\"."
      end

      desc "status", "Delete a Tweet."
      def status
        user = client.user(:include_entities => false)
        if user.status
          unless parent_options['force']
            return unless yes? "Are you sure you want to permanently delete @#{@rcfile.default_profile[0]}'s latest status: \"#{user.status.text}\"?"
          end
          status = client.status_destroy(user.status.id, :include_entities => false, :trim_user => true)
          say "@#{@rcfile.default_profile[0]} deleted the status: \"#{status.text}\""
        else
          raise Thor::Error, "Tweet not found"
        end
      end
      map %w(post tweet update) => :status

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
