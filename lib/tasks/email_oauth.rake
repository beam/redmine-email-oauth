# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'net/imap'
require 'oauth2'
require 'uri'
require 'cgi'

require 'gmail_xoauth' unless defined?(Net::IMAP::XOauth2Authenticator) && Net::IMAP::XOauth2Authenticator.class == Class

namespace :redmine do
  namespace :email do

    # token_file = path and basename /app/redmine/config/email_token (email_token.yml and email_token_client.yml are created)
    # client = Azure app Client ID
    # secret = Azure app Secret key
    # tenant = Azure app Tenant ID

    desc "Init Office 365 authorization"
    task :o365_oauth2_init => :environment do

      token_file = ENV['token_file']
      client_id = ENV['client']
      client_secret = ENV['secret']
      tenant_id = ENV['tenant']

      scope = [
        "offline_access",
        "https://outlook.office.com/User.Read",
        "https://outlook.office.com/IMAP.AccessAsUser.All",
        "https://outlook.office.com/POP.AccessAsUser.All",
        "https://outlook.office.com/SMTP.Send",
      ]

      client_config = {
        "tenant_id" => tenant_id,
        "client_id" => client_id,
        "client_secret" => client_secret,
        "site" => 'https://login.microsoftonline.com',
        "authorize_url" => "/#{tenant_id}/oauth2/v2.0/authorize",
        "token_url" => "/#{tenant_id}/oauth2/v2.0/token"
      }

      client = OAuth2::Client.new(client_config['client_id'], client_config['client_secret'],
        site: client_config['site'], authorize_url: client_config['authorize_url'], token_url: client_config['token_url'])

      print("Go to URL: #{client.auth_code.authorize_url(scope: scope.join(" "))}\n")
      print("Enter full URL after authorize:")
      access_token = client.auth_code.get_token(CGI.parse(URI.parse(STDIN.gets.strip).query)["code"].first, client_id: client_id)

      File.write("#{token_file}.yml", access_token.to_hash.to_yaml)
      File.write("#{token_file}_client.yml", client_config.to_yaml)

      puts "AUTH OK!"
    end

    desc "Read emails from an IMAP server authorized via OAuth2"
    task :receive_imap_oauth2 => :environment do

      token_file = ENV['token_file']

      unless token_file || File.exists?("#{token_file}.yml") || File.exists?("#{token_file}_client.yml")
        raise "token_file not defined or not exists"
      end
      
      client_config = YAML.load_file("#{token_file}_client.yml")
      client = OAuth2::Client.new(client_config['client_id'], client_config['client_secret'],
        site: client_config['site'], authorize_url: client_config['authorize_url'], token_url: client_config['token_url'])

      access_token = OAuth2::AccessToken.from_hash(client, YAML.load_file("#{token_file}.yml"))

      if access_token.expired?
        access_token = access_token.refresh!
        File.write("#{token_file}.yml", access_token.to_hash.to_yaml)
      end

      imap_options = {:host => ENV['host'],
                      :port => ENV['port'],
                      :ssl => ENV['ssl'],
                      :starttls => ENV['starttls'],
                      :username => ENV['username'],
                      :password => access_token.token,
                      :auth_type => 'XOAUTH2',
                      :folder => ENV['folder'],
                      :move_on_success => ENV['move_on_success'],
                      :move_on_failure => ENV['move_on_failure']}

      Mailer.with_synched_deliveries do
        Redmine::IMAP.check(imap_options, MailHandler.extract_options_from_env(ENV))
      end
    end
  
  end

end
